require 'http/cookie'
require 'faraday'
require 'faraday-cookie_jar'
require 'faraday-http-cache'
require 'faraday/encoding'
require 'faraday/follow_redirects'
require 'faraday/gzip'
require 'faraday/retry'
require_relative 'url_policy'

module MetaInspector
  # Builds page and binary image transports from the same caller configuration.
  class HttpSession
    def initialize(options = {})
      @allow_redirections = options[:allow_redirections]
      @retries = options[:retries]
      @headers = options[:headers]
      @url_filter = options[:url_filter]
      if !@url_filter.nil? && !@url_filter.respond_to?(:call)
        raise ArgumentError, 'url_filter must respond to call'
      end
      @cache = cache_option(options)
      @faraday_options = (options[:faraday_options] || {}).except(:faraday_http_cache)
    end

    def build(url, image: false, origin: nil)
      URLPolicy.validate!(url)
      faraday_options = @faraday_options.merge(url: url)
      redirects = (faraday_options.delete(:redirect) || {}).dup
      Faraday.new(faraday_options) do |faraday|
        unless image
          faraday.request :retry, max: @retries
          faraday.request :gzip
        end
        if @allow_redirections
          redirects[:limit] ||= 10
          faraday.use Faraday::FollowRedirects::Middleware, **redirects
          faraday.use :cookie_jar
        end
        faraday.use URLPolicy, @url_filter, image ? origin : nil
        if !image && @cache.is_a?(Hash)
          cache_options = @cache.dup
          cache_options[:serializer] ||= Marshal
          faraday.use Faraday::HttpCache, **cache_options
        end
        faraday.headers.merge!(@headers || {})
        faraday.response :encoding unless image
        faraday.adapter :net_http
      end
    end

    private

    def cache_option(options)
      nested = (options[:faraday_options] || {})[:faraday_http_cache]
      top_level = options[:faraday_http_cache]
      return nested if top_level.nil?
      unless nested.nil?
        raise ArgumentError, 'Pass faraday_http_cache inside faraday_options or as a top-level option, not both'
      end
      Request.warn_faraday_http_cache_deprecation
      top_level
    end
  end
end
