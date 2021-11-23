# frozen_string_literal: true

class Services::ConfigurationsController < Services::ApplicationController
  before_action :ensure_in_session!
  skip_before_action :authenticate_user!

  def show
    @project_item = CustomizableProjectItem.new(session[session_key])
    if prev_visible_step.valid?
      @step = step(saved_state)
      @offer = @step.offer

      unless @step.visible?
        redirect_to url_for([@service, next_step_key])
      end
    else
      redirect_to url_for([@service, pref_visible_step_key]), alert: prev_visible_step.error
    end
  end

  def update
    @step = step(configuration_params)
    @project_item = CustomizableProjectItem.new(configuration_params)

    if @step.request_voucher
      @step.voucher_id = ""
    end

    if @step.valid?
      save_in_session(@step)
      redirect_to url_for([@service, next_step_key])
    else
      flash.now[:alert] = @step.error
      render :show
    end
  end

  private
    def configuration_params
      template = CustomizableProjectItem.new(saved_state)
      saved_state
          .merge(permitted_attributes(template))
          .merge(status: :created)
    end

    def step_key
      :configuration
    end
end
