# frozen_string_literal: true

require "uri"
require "net/http"

module UrlHelper
  def self.media_url_valid?(url, content_type = "image/*")
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTP)
      return false
    end

    headers = { "Content-Type" => content_type }
    response = Faraday.get(url, headers)
    response.status == 200
  rescue URI::InvalidURIError, NoMethodError
    false
  end

  def self.url_valid?(url)
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTP)
      return false
    end

    response = Faraday.get(url)
    response.status == 200
  rescue URI::InvalidURIError, NoMethodError, Faraday::Error
    false
  end
end
