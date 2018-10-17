# frozen_string_literal: true

require "rails_helper"

RSpec.feature "Service project_item" do
  include OmniauthHelper

  context "as logged in user" do

    let(:user) { create(:user) }
    let(:service) { create(:service) }

    before { checkin_sign_in_as(user) }

    scenario "I see project_item service button" do
      visit service_path(service)

      expect(page).to have_text("ProjectItem")
    end

    scenario "I see project_item open acces service button" do
      @open_access_service = create(:open_access_service)
      visit service_path(@open_access_service)

      expect(page).to have_text("Add to my services")
    end

    scenario "I can add project_item to cart" do
      visit service_path(service)

      click_button "ProjectItem"

      expect(page).to have_current_path(new_project_item_path)
      expect(page).to have_text(service.title)
      expect(page).to have_selector(:link_or_button,
                                    "ProjectItem", exact: true)

      expect { click_on "ProjectItem" }.
        to change { ProjectItem.count }.by(1)
      project_item = ProjectItem.last

      expect(project_item.service_id).to eq(service.id)
      expect(page).to have_content(service.title)
    end

    scenario "I can project_item open acces service" do
      @open_access_service = create(:open_access_service)

      visit service_path(@open_access_service)

      click_button "Add to my services"

      expect(page).to have_current_path(new_project_item_path)
      expect(page).to have_text(@open_access_service.title)
      expect(page).to have_selector(:link_or_button,
                                    "ProjectItem", exact: true)
    end

    scenario "I can see my project_itemed services" do
      create(:project_item, user: user, service: service)

      visit project_items_path

      expect(page).to have_text(service.title)
    end

    scenario "I can see project_item details" do
      project_item = create(:project_item, user: user, service: service)

      visit project_item_path(project_item)

      expect(page).to have_text(project_item.service.title)
    end

    scenario "I cannot se other users project_items" do
      other_user_project_item = create(:project_item, service: service)

      visit project_item_path(other_user_project_item)

      expect(page).to_not have_text(other_user_project_item.service.title)
      expect(page).to have_text("not authorized")
    end

    scenario "I can see project_item change history" do
      project_item = create(:project_item, user: user, service: service)

      project_item.new_change(status: :created, message: "ProjectItem created")
      project_item.new_change(status: :registered, message: "ProjectItem registered")
      project_item.new_change(status: :ready, message: "ProjectItem ready")

      visit project_item_path(project_item)

      expect(page).to have_text("Current status: ready")

      expect(page).to have_text("ProjectItem created")

      expect(page).to have_text("ProjectItem changed from created to registered")
      expect(page).to have_text("ProjectItem registered")

      expect(page).to have_text("ProjectItem changed from registered to ready")
      expect(page).to have_text("ProjectItem registered")
    end

    scenario "I can ask question about my project_item" do
      project_item = create(:project_item, user: user, service: service)

      visit project_item_path(project_item)
      fill_in "project_item_question_text", with: "This is my question"
      click_button "Send message"

      expect(page).to have_text("This is my question")
    end

    scenario "question message is mandatory" do
      project_item = create(:project_item, user: user, service: service)

      visit project_item_path(project_item)
      click_button "Send message"

      expect(page).to have_text("Question cannot be blank")
    end
  end

  context "as anonymous user" do

    scenario "I nead to login to project_item" do
      service = create(:service)
      user = create(:user)

      visit service_path(service)

      expect(page).to have_selector(:link_or_button, "ProjectItem", exact: true)

      click_on "ProjectItem"

      checkin_sign_in_as(user)

      expect(page).to have_current_path(new_project_item_path)
      expect(page).to have_text(service.title)
    end

    scenario "I can see project_item button" do
      service = create(:service)

      visit service_path(service)

      expect(page).to have_selector(:link_or_button, "ProjectItem", exact: true)
    end

    scenario "I can see openaccess service project_item button" do
      open_access_service =  create(:open_access_service)

      visit service_path(open_access_service)

      expect(page).to have_selector(:link_or_button, "Add to my services", exact: true)
      expect(page).to have_selector(:link_or_button, "Go to the service", exact: true)
    end

    scenario "I don't see my services page" do
      visit root_path

      expect(page).to_not have_text("My services")
    end
  end
end
