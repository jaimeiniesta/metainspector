require 'http/cookie'
require 'faraday'
require 'faraday-cookie_jar'
require 'faraday-http-cache'
require 'faraday/encoding'
require 'faraday/follow_redirects'
require 'faraday/gzip'
require 'faraday/retry'
require_relative 'url_policy'
require_relative 'limited_response'
require_relative 'attempt_timeout'

module MetaInspector
  # Builds page and binary image transports from the same caller configuration.
  class HttpSession
    # Faraday stores the query as a params hash and rebuilds it for the request,
    # which sorts keys, drops repeated ones and re-escapes values. This encoder
    # keeps the whole query as a single key, so it is sent as written.
    module RawQuery
      def self.decode(query)
        query.to_s.empty? ? {} : { query => nil }
      end

      def self.encode(params)
        params.keys.join('&')
      end
    end

    def initialize(options = {})
      @allow_redirections = options[:allow_redirections]
      @retries = options[:retries]
      @attempt_timeout = (options[:connection_timeout] || 0) + (options[:read_timeout] || 0) + 1
      @headers = options[:headers]
      @max_html_bytes = options[:max_html_bytes]
      @url_filter = options[:url_filter]
      if !@url_filter.nil? && !@url_filter.respond_to?(:call)
        raise ArgumentError, 'url_filter must respond to call'
      end
      @cache = (options[:faraday_options] || {})[:faraday_http_cache]
      @faraday_options = (options[:faraday_options] || {}).except(:faraday_http_cache)
    end

    def build(url, image: false, origin: nil, protect_redirect_callback: false)
      uri = URLPolicy.validate!(url)
      # Image requests must keep trusting the initial origin after page redirects.
      @page_origin ||= url.to_s unless image
      # Faraday.new decodes a query in its URL with the default encoder, before
      # any configured one applies, so the query is added to the params below.
      query = uri.query
      uri.query = nil
      faraday_options = @faraday_options.merge(url: uri.to_s)
      faraday_options[:request] = { params_encoder: RawQuery }.merge(faraday_options[:request] || {})
      redirects = (faraday_options.delete(:redirect) || {}).dup
      if protect_redirect_callback && redirects[:callback]
        callback = redirects[:callback]
        redirects[:callback] = lambda do |*args|
          begin
            callback.call(*args)
          rescue StandardError => error
            raise URLPolicy::Failure.new(error)
          end
        end
      end
      connection = Faraday.new(faraday_options) do |faraday|
        unless image
          faraday.request :retry, max: @retries
          faraday.use AttemptTimeout, @attempt_timeout
          # Responses run in reverse order: decompress before applying the charset.
          faraday.response :encoding
          faraday.request :gzip if @max_html_bytes.nil?
        end
        if @allow_redirections
          redirects[:limit] ||= 10
          faraday.use Faraday::FollowRedirects::Middleware, **redirects
          faraday.use :cookie_jar
        end
        faraday.use URLPolicy, @url_filter, image ? origin : nil,
          request_origin: @page_origin || origin
        faraday.use LimitedResponse, @max_html_bytes if !image && @max_html_bytes
        if !image && @cache.is_a?(Hash)
          cache_options = @cache.dup
          cache_options[:serializer] ||= Marshal
          faraday.use Faraday::HttpCache, **cache_options
        end
        faraday.use LimitedResponse::Streaming, @max_html_bytes if !image && @max_html_bytes
        faraday.headers.merge!(@headers || {})
        faraday.adapter :net_http
      end
      connection.params.merge_query(query, connection.options.params_encoder)
      connection
    end
  end
end
