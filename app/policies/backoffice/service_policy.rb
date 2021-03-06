# frozen_string_literal: true


class Backoffice::ServicePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.service_portfolio_manager?
        scope
      elsif user.service_owner?
        scope.joins(:service_user_relationships).
          where(service_user_relationships: { user: user })
      else
        Service.none
      end
    end
  end

  MP_INTERNAL_FIELDS = [
    [platform_ids: []],
    :restrictions,
    :status,
    :activate_message,
    :upstream_id,
    [owner_ids: []],
    sources_attributes: [:id, :source_type, :eid, :_destroy]
  ]

  def index?
    service_portfolio_manager? || service_owner?
  end

  def show?
    service_portfolio_manager? || owned_service?
  end

  def new?
    service_portfolio_manager?
  end

  def create?
    service_portfolio_manager?
  end

  def update?
    (service_portfolio_manager? ||
     owned_service?) &&
    !record.deleted?
  end

  def publish?
    service_portfolio_manager? &&
      (record.draft? || record.unverified?) &&
      !record.deleted?
  end

  def publish_unverified?
    service_portfolio_manager? &&
      (record.draft? || record.published?) &&
      !record.deleted?
  end

  def draft?
    service_portfolio_manager? &&
      (record.published? || record.unverified?) &&
      !record.deleted?
  end

  def preview?
    service_portfolio_manager?
  end

  def destroy?
    service_portfolio_manager? &&
      (project_items && project_items.count.zero?) &&
      record.draft?
  end

  def permitted_attributes
    attrs = [
      { sources_attributes: [:id, :source_type, :eid, :_destroy] },
      :name, :description,
      :tagline, :order_type,
      [provider_ids: []], [geographical_availabilities: []],
      [language_availability: []], [resource_geographic_locations: []],
      [target_user_ids: []], :terms_of_use_url,
      :access_policies_url, :sla_url,
      :webpage_url, :manual_url, :helpdesk_url,
      :helpdesk_email, :security_contact_email, :training_information_url,
      :privacy_policy_url, [use_cases_url: []], :restrictions,
      :status_monitoring_url, :maintenance_url,
      :order_url, :payment_model_url, :pricing_url,
      [funding_body_ids: []], [funding_program_ids: []],
      [access_type_ids: []], [access_mode_ids: []],
      [certifications: []], [standards: []],
      [grant_project_names: []], [open_source_technologies: []],
      [changelog: []], [multimedia: []],
      :activate_message, :logo, [trl_ids: []],
      [scientific_domain_ids: []], [related_platforms: []],
      [platform_ids: []], :tag_list, [category_ids: []], [pc_category_ids: []],
      [related_service_ids: []], [required_service_ids: []],
      [manual_related_service_ids: []],
      [owner_ids: []], :status, :upstream_id, :version,
      [life_cycle_status_ids: []], :resource_organisation_id,
      { main_contact_attributes: [:id, :first_name, :last_name, :email, :phone, :organisation, :position] },
      { public_contacts_attributes: [:id,
                                     :first_name,
                                     :last_name,
                                     :email,
                                     :phone,
                                     :organisation,
                                     :position,
                                     :_destroy] }
    ]

    if !@record.is_a?(Service) || @record.upstream.nil?
      attrs
    else
      MP_INTERNAL_FIELDS
    end
  end

  private
    def service_portfolio_manager?
      user&.service_portfolio_manager?
    end

    def service_owner?
      user&.service_owner?
    end

    def owned_service?
      record.owned_by?(user)
    end

    def project_items
      ProjectItem.joins(:offer).where(offers: { service_id: record })
    end
end
