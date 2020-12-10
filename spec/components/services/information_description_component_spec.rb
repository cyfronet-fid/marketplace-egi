# frozen_string_literal: true

require "rails_helper"

RSpec.describe Services::InformationDescriptionComponent, type: :component do
  [:open_access, :fully_open_access, :other].each do |type|
    it "shows correct information page for #{type} order type" do
      service = create(:service, order_type: type)
      offer = create(:offer, service: service, order_type: type)

      render_inline(Services::InformationDescriptionComponent.new(order_type: type,
                                                                  service_title: service.name,
                                                                  offer: offer))

      expect(page).to have_text("\nThis is an open access offer of the #{service.name} resource." +
                                "\nPress\nGo to the resource\nbutton to reach the resource website." +
                                "\nYou may also add the resource to a\nProject\nin order to:" +
        "\n\nGain EOSC experts support\nEasily access the selected resource" +
        "\nOrganise your resources and orders into logical blocks\n\n\n\n" +
        "To find out more about Projects in EOSC Marketplace, please refer to our\nFAQ")
    end
  end

  it "shows correct information page for order_required order type" do
    service = create(:service, order_type: :order_required)
    offer = create(:offer, service: service, order_type: :order_required, internal: true)

    render_inline(Services::InformationDescriptionComponent.new(order_type: :order_required,
                                                                service_title: service.name,
                                                                offer: offer))

    expect(page).to have_text("This resource can be ordered via EOSC Marketplace. " +
      "Once the information provided in the details\nof the underpinned Project is verified, " +
      "the resource will be delivered to you by the resource provider.\n\n\n" +
      "To access the resource:\n\nPlace an order to request access\nYou will receive " +
      "the summary of your order via email\nYou will be contacted by the support team " +
      "once the resource is ready for you to use\n\n\n\nYour resource request status changes " +
      "can be tracked in the project's dashboard." +
      "\nTo find out more about Projects in EOSC Marketplace, please refer to our\nFAQ")
  end

  it "shows correct information page for external order type" do
    service = create(:external_service)
    offer = create(:external_offer, service: service)

    render_inline(Services::InformationDescriptionComponent.new(order_type: :external,
                                                                service_title: service.name,
                                                                offer: offer))

    expect(page).to have_text("To use this resource you need to request access at the provider’s website." +
                              "\nPress\nGo to the resource\nbutton to visit it.\n" +
                              "You may also add the resource to a\nProject\nin order to:\n\n" +
                              "Gain EOSC experts support\nEasily access the selected resource" +
                              "\nOrganise your resources and orders into logical blocks\n\n\n\n" +
                              "To find out more about Projects in EOSC Marketplace, " +
                              "please refer to our\nFAQ")
  end
end