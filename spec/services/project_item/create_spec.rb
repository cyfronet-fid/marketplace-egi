# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectItem::Create do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:service) { create(:service) }
  let(:offer) { create(:offer, service: service) }
  let(:project_item_template) { build(:customizable_project_item, project: project, offer: offer) }

  it "creates project_item and set initial project_item status" do
    project_item = described_class.new(project_item_template).call

    expect(project_item).to be_created
    expect(project_item.user).to eq(user)
    expect(project_item.service).to eq(service)
  end

  it "creates first project_item status" do
    project_item = described_class.new(project_item_template).call

    expect(project_item.status).to eq("created")
    expect(project_item).to be_created
    expect(project_item.statuses.count).to eq(1)
    expect(project_item.statuses.first.status).to eq("created")
    expect(project_item.statuses.first).to be_created
  end

  it "triggers register project_item in external system" do
    project_item = described_class.new(project_item_template).call

    expect(ProjectItem::RegisterJob).to have_been_enqueued.with(project_item, nil)
  end

  context "for service with :eosc_registry upstream" do
    let(:service) { create(:service, pid: "foo") }
    let(:upstream) { build(:eosc_registry_service_source) }

    before do
      upstream.update!(service: service)
      service.update!(upstream: upstream)
    end

    it "enqueues publish jobs" do
      described_class.new(project_item_template).call

      expect(Jms::PublishJob).to have_been_enqueued.twice
    end
  end

  it "doesn't enqueue publish jobs" do
    described_class.new(project_item_template).call

    expect(Jms::PublishJob).not_to have_been_enqueued
  end

  context "when open_access service has been added to Project" do
    let(:service) { create(:open_access_service) }

    it "sends email to project_item owner - added to the project" do
      expect { described_class.new(project_item_template).call }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  context "when external service has been added to Project" do
    let(:service) { create(:external_service) }

    it "sends email to project_item owner - added to the project" do
      expect { described_class.new(project_item_template).call }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  context "when orderable service has been ordered" do
    it "sends email to project_item owner" do
      expect { described_class.new(project_item_template).call }.
        to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  context "#bundle" do
    let(:offer) { create(:offer, service: service) }
    let(:service1) { create(:service) }
    let(:child1) { create(:offer, service: service1) }
    let(:service2) { create(:service) }
    let(:child2) { create(:offer, service: service2) }

    let(:project_item_template) { build(:project_item, project: project, offer: offer) }

    before do
      OfferLink.create!(source: offer, target: child1)
      OfferLink.create!(source: offer, target: child2)
    end

    it "creates bundled project_items" do
      expect { described_class.new(project_item_template, "test-msg", bundle_params: {}).call }
        .to change { ActionMailer::Base.deliveries.count }.by(3).
          and change { ProjectItem.count }.by(3)

      ProjectItem.all.each do |project_item|
        expect(ProjectItem::RegisterJob).to have_been_enqueued.with(project_item, "test-msg")
      end
    end

    context "with error" do
      let(:child2) { create(:offer_with_parameters, service: service) }

      it "creates nothing" do
        expect { described_class.new(project_item_template, "test-msg", bundle_params: {}).call }
          .to change { ActionMailer::Base.deliveries.count }.by(0).
            and change { ProjectItem.count }.by(0)

        expect(ProjectItem::RegisterJob).not_to have_been_enqueued
      end
    end
  end
end
