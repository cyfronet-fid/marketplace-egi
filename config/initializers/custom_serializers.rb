# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Specify serializers for custom objects.
Rails.application.reloader.to_prepare do
  Rails.application.config.active_job.custom_serializers << ReportsSerializer
end
