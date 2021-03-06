# frozen_string_literal: true

require "mini_magick"

class Import::Providers
  def initialize(eosc_registry_base_url,
                 dry_run: true,
                 filepath: nil,
                 faraday: Faraday,
                 logger: ->(msg) { puts msg },
                 ids: [],
                 default_upstream: :mp,
                 token: nil)
    @eosc_registry_base_url = eosc_registry_base_url
    @dry_run = dry_run
    @faraday = faraday
    @default_upstream = default_upstream
    @token = token
    @ids = ids

    @logger = logger
    @filepath = filepath

    @updated_count = 0
    @created_count = 0
  end

  def call
    log "Importing providers from EOSC Registry..."
    @request_providers = get_external_providers_data.select { |id, _| @ids.empty? || @ids.include?(id) }
    @request_providers.each do |eid, external_provider_data|
      parsed_provider_data = Importers::Provider.new(external_provider_data, Time.now.to_i, "rest").call
      eosc_registry_provider = Provider.joins(:sources).
        find_by("provider_sources.source_type": "eosc_registry", "provider_sources.eid": eid)
      current_provider = eosc_registry_provider || Provider.find_by(name: parsed_provider_data[:name])

      provider_source = ProviderSource.find_by(source_type: "eosc_registry", eid: eid)

      # Bug fix for duplicated sources
      if @default_upstream == :eosc_registry && provider_source.present?
        current_provider.update(upstream_id: provider_source.id)
      end

      if @dry_run
        next
      end

      if current_provider.blank?
        create_provider(parsed_provider_data, external_provider_data["logo"], eid)
      elsif provider_source.present? && provider_source.id == current_provider.upstream_id
        update_provider(current_provider, parsed_provider_data, external_provider_data["logo"])
      end
      rescue ActiveRecord::RecordInvalid
        log "[WARN] Provider #{parsed_provider_data[:name]},
                eid: #{parsed_provider_data[:pid]} cannot be updated. #{current_provider.errors.full_messages}"
      ensure
        log_status(current_provider, parsed_provider_data, provider_source)
    end

    Provider.reindex

    not_modified = @request_providers.length - @created_count - @updated_count
    log "PROCESSED: #{@request_providers.length}, CREATED: #{@created_count}, " +
          "UPDATED: #{@updated_count}, NOT MODIFIED: #{not_modified}"

    unless @filepath.nil?
      open(@filepath, "w") do |file|
        file << JSON.pretty_generate(@request_providers.map { |_, request_data| request_data })
      end
    end
  end

  private
    def log(msg)
      @logger.call(msg)
    end

    def log_status(current_provider, parsed_provider_data, provider_source)
      if current_provider.blank?
        @created_count += 1
        log "Adding [NEW] provider: #{parsed_provider_data[:name]}, eid: #{parsed_provider_data[:pid]}"
      elsif provider_source.present? && provider_source.id == current_provider.upstream_id
        @updated_count += 1
        log "Updating [EXISTING] provider: #{parsed_provider_data[:name]}, eid: #{parsed_provider_data[:pid]}"
      else
        log "Provider upstream is not set to EOSC Registry, " +
              "not updating #{current_provider.name}, id: #{current_provider.pid}"
      end
    end

    def create_provider(parsed_provider_data, image_url, eid)
      current_provider = Provider.new(parsed_provider_data)
      current_provider.set_default_logo
      current_provider.save(validate: false)
      provider_source = ProviderSource.create!(
        provider_id: current_provider.id,
        source_type: "eosc_registry",
        eid: eid
      )
      current_provider.upstream_id = provider_source.id
      if current_provider.invalid?
        provider_source.update!(errored: current_provider.errors.to_hash)
        log "Provider #{parsed_provider_data[:name]},
              eid: #{parsed_provider_data[:pid]} saved with errors: #{current_provider.errors.full_messages}"
      end

      Importers::Logo.new(current_provider, image_url).call
      current_provider.save(validate: false)
    end

    def update_provider(current_provider, parsed_provider_data, image_url)
      current_provider.update(parsed_provider_data)
      if current_provider.valid?
        current_provider.save!

        Importers::Logo.new(current_provider, image_url).call
        current_provider.save!
      else
        current_provider.sources.first.update!(errored: current_provider.errors.to_hash)
      end
    end

    def get_external_providers_data
      begin
        rp = Importers::Request.new(@eosc_registry_base_url, "provider", faraday: @faraday, token: @token).call
      rescue Errno::ECONNREFUSED
        abort("import exited with errors - could not connect to #{@eosc_registry_base_url}")
      end
      rp.body["results"].index_by { |provider| provider["id"] }
    end
end
