# frozen_string_literal: true

require "#{Rails.root}/app/helpers/image_helper"

namespace :dev do
  include ImageHelper

  desc "Sample data for local development environment"
  task prime: "db:setup" do
    create_all_from_path("db/data.yml")
    puts "Done!"
  end

  desc "Sample data for e2e tests"
  task prime_e2e: "db:setup" do
    create_all_from_path("db/data_e2e.yml")
    puts "Done!"
  end

  def create_all_from_path(path)
    yaml_hash = YAML.load_file(path)

    create_vocabularies
    create_categories(yaml_hash["categories"])
    create_providers(yaml_hash["providers"])
    create_scientific_domains(yaml_hash["domain"])
    create_platforms(yaml_hash["platforms"])
    create_target_users(yaml_hash["target_users"])
    create_services(yaml_hash["services"])
    create_relations(yaml_hash["relations"])

    OrderingApi::AddSombo.new.call
  end

  def create_categories(categories_hash)
    puts "Generating categories:"
    categories_hash.each do |_, hash|
      Category.find_or_initialize_by(name: hash["name"]) do |category|
        category.update!(description: hash["description"],
                        parent: Category.find_by(name: hash["parent"]))
        puts "  - #{hash["name"]} category generated"
      end
    end
  end

  def create_providers(providers_hash)
    puts "Generating providers:"
    providers_hash.each do |_, hash|
      provider = Provider.find_or_initialize_by(name: hash["name"])
      provider.abbreviation = hash["abbreviation"]
      provider.website = hash["website"]
      provider.legal_entity = hash["legal_entity"]
      provider.description = hash["description"]
      provider.street_name_and_number = hash["street_name_and_number"]
      provider.postal_code = hash["postal_code"]
      provider.city = hash["city"]
      provider.country = Country.for(hash["country_alpha2"])
      provider.pid = provider.abbreviation
      provider.status = hash["status"]

      io, extension = ImageHelper.base_64_to_blob_stream(hash["image_base_64"])
      provider.logo.attach(
        io: io,
        filename: provider.pid + extension,
        content_type: "image/#{extension.delete!(".", "")}"
      )

      provider.save(validate: false)
      puts "  - #{hash["name"]} provider generated"
    end
  end

  def create_scientific_domains(scientific_domains_hash)
    puts "Generating scientific domains:"
    scientific_domains_hash.each do |_, hash|
      # !!! Warning: parent need to be defined before child in yaml !!!
      parent = ScientificDomain.find_by(name: hash["parent"])
      ScientificDomain.find_or_initialize_by(name: hash["name"]) do |sd|
        sd.update!(parent: parent)
      end
      puts "  - #{hash["name"]} scientific domain generated"
    end
  end

  def create_platforms(platforms_hash)
    puts "Generating platforms:"
    platforms_hash.each do |_, hash|
      Platform.find_or_create_by(name: hash["name"])
      puts "  - #{hash["name"]} platforms generated"
    end
  end

  def create_target_users(target_users_hash)
    puts "Generating target groups:"
    target_users_hash.each do |_, hash|
      TargetUser.find_or_create_by(name: hash["name"])
      puts "  - #{hash["name"]} target group generated"
    end
  end

  def create_services(services_hash)
    puts "Generating services:"
    services_hash.each do |_, hash|
      categories = Category.where(name: hash["parents"])
      providers = Provider.where(name: hash["providers"])
      domain = ScientificDomain.where(name: hash["domain"])
      resource_organisation = Provider.find_by(name: "not specified yet")
      platforms = Platform.where(name: hash["platforms"])
      funding_bodies = Vocabulary::FundingBody.where(eid: hash["funding_bodies"])
      funding_programs = Vocabulary::FundingProgram.where(eid: hash["funding_programs"])
      service = Service.find_or_initialize_by(name: hash["name"])
      trl = Vocabulary::Trl.where(eid: hash["trl"])
      life_cycle_status = Vocabulary::LifeCycleStatus.where(eid: hash["life_cycle_status"])
      target_users = TargetUser.where(name: hash["target_users"])
      order_type = order_type_from(hash)

      service.assign_attributes(pid: hash["pid"] || nil,
                      tagline: hash["tagline"],
                      description: hash["description"],
                      scientific_domains: domain,
                      providers: providers,
                      order_type: order_type,
                      order_url: hash["order_url"] || "",
                      resource_organisation: resource_organisation,
                      webpage_url: hash["webpage_url"],
                      manual_url: hash["manual_url"],
                      helpdesk_url: hash["helpdesk_url"],
                      training_information_url: hash["training_information_url"],
                      funding_bodies: funding_bodies,
                      funding_programs: funding_programs,
                      terms_of_use_url: hash["terms_of_use_url"],
                      sla_url: hash["sla_url"],
                      access_policies_url: hash["access_policies_url"],
                      language_availability: hash["language_availability"],
                      geographical_availabilities: [hash["geographical_availabilities"]],
                      target_users: target_users,
                      restrictions: hash["restrictions"],
                      trl: trl,
                      life_cycle_status: life_cycle_status,
                      categories: categories,
                      tag_list: hash["tags"],
                      platforms: platforms,
                      status: :published)
      service.save(validate: false)

      service.logo.attached? && service.logo.purge_later
      hash["logo"] && service.logo.attach(io: File.open("db/logos/#{hash["logo"]}"), filename: hash["logo"])
      puts "  - #{hash["name"]} service generated"

      create_offers(service, hash["offers"])
    end
  end

  def order_type_from(hash)
    if hash["external"]
      "order_required"
    else
      hash["open_access"] ? "open_access" : "order_required"
    end
  end

  def create_offers(service, offers_hash)
    offers_hash && offers_hash.each do |_, h|
      effective_order_url = h["order_url"] || service.order_url
      service.offers.create!(name: h["name"],
                            description: h["description"],
                            parameters: Parameter::Array.load(h["parameters"] || []),
                            order_type: h["order_type"].blank? ? service.order_type : h["order_type"],
                            order_url: effective_order_url.present? ? effective_order_url : "",
                            internal: effective_order_url.blank?,
                            status: :published)
      puts "    - #{h["name"]} offer generated"
    end
  end

  def create_relations(relations_hash)
    puts "Generating service relations from yaml (remove all relations and crating new one):"
    ServiceRelationship.delete_all

    relations_hash && relations_hash.each do |_, hash|
      source = Service.find_by(name: hash["source"])
      target = Service.find_by(name: hash["target"])
      ManualServiceRelationship.create!(source: source, target: target)
      if hash["both"]
        ManualServiceRelationship.create!(source: target, target: source)
        puts "  - Relation from #{target.name} to #{source.name} generated"
      end
      puts "  - Relation from #{source.name} to #{target.name} generated"
    end
  end

  def create_vocabularies
    Rake::Task["rdt:add_vocabularies"].invoke
  end
end
