# frozen_string_literal: true

require "rails_helper"
require "jira/setup"

describe Import::EIC do
  test_url = "https://localhost"

  let(:unirest) { double }
  let(:eic) { Import::EIC.new(test_url, false, false, unirest) }
  let!(:research_area_other) { create(:research_area, name: "Other") }
  let!(:storage) { create(:category, name: "Storage") }
  let!(:training) { create(:category, name: "Training & Support") }
  let!(:security) { create(:category, name: "Security & Operations") }
  let!(:analytics) { create(:category, name: "Processing & Analysis") }
  let!(:data) { create(:category, name: "Data management") }
  let!(:compute) { create(:category, name: "Compute") }
  let!(:networking) { create(:category, name: "Networking") }

  def expect_responses(unirest, test_url, services_response = nil, providers_response = nil)
    unless services_response.nil?
      expect(unirest).to receive(:get).with("#{test_url}/api/service/rich/all?quantity=10000&from=0",
                                            headers: { "Accept" => "application/json" }).and_return(services_response)
    end

    unless providers_response.nil?
      expect(unirest).to receive(:get).with("#{test_url}/api/provider/all?quantity=10000&from=0",
                                            headers: { "Accept" => "application/json" }).and_return(providers_response)
    end
  end

  describe "#error responses" do
    it "should abort if /api/services errored" do
      response = double(code: 500, body: {})
      expect_responses(unirest, test_url, response)
      expect { eic.call }.to raise_error(SystemExit)
    end

    it "should abort if /api/providers errored" do
      response = double(code: 200, body: create(:eic_services_response))
      provider_response = double(code: 500, body: {})
      expect_responses(unirest, test_url, response, provider_response)

      eic = Import::EIC.new(test_url, false, true, unirest)
      expect { eic.call }.to raise_error(SystemExit)
    end
  end

  describe "#standard responses" do
    before(:each) do
      response = double(code: 200, body: create(:eic_services_response))
      provider_response = double(code: 200, body: create(:eic_providers_response))
      expect_responses(unirest, test_url, response, provider_response)
    end

    it "should not create if 'dont_create_providers' is set to true" do
      eic = Import::EIC.new(test_url, false, true, unirest)
      expect { eic.call }.to change { Provider.count }.by(0)
    end

    it "should create provider if it didn't exist and add external source for it" do
      expect { eic.call }.to change { Provider.count }.by(1)
      provider = Provider.first

      expect(provider.sources.count).to eq(1)
      expect(provider.sources.first.eid).to eq("phenomenal")
      expect(provider.sources.first.source_type).to eq("eic")
    end

    it "should create service if none existed" do
      expect { eic.call }.to output(/PROCESSED: 1, CREATED: 1, UPDATED: 0, NOT MODIFIED: 0$/).to_stdout.and change { Service.count }.by(1)

      service = Service.first

      expect(service.title).to eq("PhenoMeNal")
      expect(service.description).to eq("PhenoMeNal (Phenome and Metabolome aNalysis) is a comprehensive and standardised " +
                                            "e-infrastructure that supports the data processing and analysis pipelines for molecular " +
                                            "phenotype data generated by metabolomics applications.\n\n\nPhenoMeNal allows you to deploy " +
                                            "your own Cloud Research Environment (CRE) for Metabolomics data analysis on private and public " +
                                            "cloud providers, an Application Library listing open source tools and  online training tutorials\n" +
                                            "Reproducible Metabolomics processing and analysis pipeline without the need for expert installation " +
                                            "and maintenance\nWorldwide, individual researchers and larger labs with either commercial cloud-based or in-house deployments.")
      expect(service.tagline).to eq("Large-Scale computing for medical metabolomics")
      expect(service.connected_url).to eq("https://portal.phenomenal-h2020.eu/home")
      expect(service.places).to eq("World")
      expect(service.languages).to eq("English")
      expect(service.dedicated_for).to eq([])
      expect(service.terms_of_use_url).to eq("http://phenomenal-h2020.eu/home/wp-content/uploads/2016/09/Phenomenal-Terms-of-Use-version-11.pdf")
      expect(service.access_policies_url).to eq("http://phenomenal-h2020.eu/home/wp-content/uploads/2016/09/Phenomenal-Terms-of-Use-version-11.pdf")
      expect(service.corporate_sla_url).to eq("http://phenomenal-h2020.eu/home/wp-content/uploads/2016/09/Phenomenal-Terms-of-Use-version-11.pdf")
      expect(service.webpage_url).to eq("https://portal.phenomenal-h2020.eu/home")
      expect(service.manual_url).to eq("https://github.com/phnmnl/phenomenal-h2020/wiki")
      expect(service.helpdesk_url).to eq("http://phenomenal-h2020.eu/home/help")
      expect(service.tutorial_url).to eq("http://phenomenal-h2020.eu/home/training-online")
      expect(service.phase).to eq("beta")
      expect(service.service_type).to eq("open_access")
      expect(service.status).to eq("draft")
      expect(service.providers).to eq([Provider.first])
      expect(service.categories).to eq([])
      expect(service.research_areas).to eq([research_area_other])
      expect(service.sources.count).to eq(1)
      expect(service.sources.first.eid).to eq("phenomenal.phenomenal")
    end

    it "should not update service which has upstream to null" do
      service = create(:service)
      create(:service_source, eid: "phenomenal.phenomenal", service_id: service.id, source_type: "eic")

      expect { eic.call }.to output(/PROCESSED: 1, CREATED: 0, UPDATED: 0, NOT MODIFIED: 1$/).to_stdout.and change { Service.count }.by(0)
      expect(Service.first.as_json(except: [:created_at, :updated_at])).to eq(service.as_json(except: [:created_at, :updated_at]))
    end

    it "should update service which has upstream to external id" do
      service = create(:service)
      source = create(:service_source, eid: "phenomenal.phenomenal", service_id: service.id, source_type: "eic")
      service.update!(upstream_id: source.id)

      expect { eic.call }.to output(/PROCESSED: 1, CREATED: 0, UPDATED: 1, NOT MODIFIED: 0$/).to_stdout.and change { Service.count }.by(0)
      expect(Service.first.as_json(except: [:created_at, :updated_at])).to_not eq(service.as_json(except: [:created_at, :updated_at]))
    end

    it "should not change db if dry_run is set to true" do
      eic = Import::EIC.new(test_url, true, false, unirest)
      expect { eic.call }.to output(/PROCESSED: 1, CREATED: 1, UPDATED: 0, NOT MODIFIED: 0$/).to_stdout.and change { Service.count }.by(0).and change { Provider.count }.by(0)
    end

    it "should not update research_areas and categories" do
      research_area_something = create(:research_area, name: "Something")

      service = create(:service, categories: [Category.find_by(name: "Networking")], research_areas: [research_area_something])
      source = create(:service_source, eid: "phenomenal.phenomenal", service_id: service.id, source_type: "eic")
      service.update!(upstream_id: source.id)

      eic.call

      expect(Service.first.categories).to eq(service.categories)
      expect(Service.first.research_areas).to eq(service.research_areas)
    end
  end

  it "should set placeholder tagline if it's empty" do
    response = double(code: 200, body: create(:eic_services_response, tagline: ""))
    provider_response = double(code: 200, body: create(:eic_providers_response))
    expect_responses(unirest, test_url, response, provider_response)

    eic = Import::EIC.new(test_url, false, false, unirest)

    eic.call

    expect(Service.first.tagline).to eq("NO IMPORTED TAGLINE")

  end

  it "should correctly map trls" do
    expect(eic.map_phase("trl-7")).to eq("beta")
    expect(eic.map_phase("trl-8")).to eq("production")
    expect(eic.map_phase("trl-9")).to eq("production")
    expect(eic.map_phase("trl-unknown")).to eq("discovery")
  end

  it "should have correct category mapping" do
    eic.get_db_dependencies

    expect(eic.map_category("storage")).to eq([storage])
    expect(eic.map_category("training")).to eq([training])
    expect(eic.map_category("security")).to eq([security])
    expect(eic.map_category("analytics")).to eq([analytics])
    expect(eic.map_category("data")).to eq([data])
    expect(eic.map_category("compute")).to eq([compute])
    expect(eic.map_category("networking")).to eq([networking])
    expect(eic.map_category("unknown")).to eq([])
  end
end
