# frozen_string_literal: true

class UserActionController < ApplicationController
  # Store user action in recommendation system
  def create
    if Mp::Application.config.recommender_host.nil?
      return
    end

    request_body = {
      timestamp: params[:timestamp],
      source: JSON.parse(params[:source].to_json),
      target: JSON.parse(params[:target].to_json),
      action: JSON.parse(params[:user_action].to_json)
    }

    unless current_user.nil?
      request_body[:user_id] = current_user.id
    end

    request_body[:unique_id] = cookies[:client_uid]

    unless request_body[:source]["root"]["service_id"].nil?
      request_body[:source]["root"]["service_id"] = request_body[:source]["root"]["service_id"].to_i
    end

    is_recommendation_panel = params[:source]["root"]["type"] != "other"
    if is_recommendation_panel
      request_body[:source]["root"]["panel_id"] = ab_test(:recommendation_panel)
    end

    Probes::ProbesJob.perform_later(request_body.to_json)
  end
end
