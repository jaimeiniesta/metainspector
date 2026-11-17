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
      @retries            = options[:retries]
      @attempt_timeout    = (options[:connection_timeout] || 0) + (options[:read_timeout] || 0) + 1
      @headers            = options[:headers]
      @max_html_bytes     = options[:max_html_bytes]
      @url_filter         = options[:url_filter]
      if !@url_filter.nil? && !@url_filter.respond_to?(:call)
        raise ArgumentError, 'url_filter must respond to call'
      end
      faraday_options  = options[:faraday_options] || {}
      @cache           = faraday_options[:faraday_http_cache]
      @faraday_options = faraday_options.except(:faraday_http_cache)
    end

    # Builds a connection for a page request or, with image: true, for an image
    # lookup. Image lookups skip retries, the attempt deadline, decompression,
    # the HTML size limit and the cache.
    def build(url, image: false, origin: nil, protect_redirect_callback: false)
      uri = URLPolicy.validate!(url)
      # Image requests must keep trusting the initial origin after page redirects.
      @page_origin ||= url.to_s unless image
      # Faraday.new decodes a query in its URL with the default encoder, before
      # any configured one applies, so the query is added to the params after.
      query = uri.query
      uri.query = nil
      faraday_options = @faraday_options.merge(url: uri.to_s)
      faraday_options[:request] = { params_encoder: RawQuery }.merge(faraday_options[:request] || {})
      redirects = redirect_options(faraday_options.delete(:redirect), protect_redirect_callback)

      connection = Faraday.new(faraday_options) do |faraday|
        page_middleware(faraday) unless image
        if @allow_redirections
          faraday.use Faraday::FollowRedirects::Middleware, **redirects
          faraday.use :cookie_jar
        end
        faraday.use URLPolicy, @url_filter, image ? origin : nil, request_origin: @page_origin || origin
        page_limit_and_cache_middleware(faraday) unless image
        faraday.headers.merge!(@headers || {})
        faraday.adapter :net_http
      end
      connection.params.merge_query(query, connection.options.params_encoder)
      connection
    end

    private

    # With protect_callback, errors raised by the caller's redirect callback
    # bypass the rescue clauses for network errors, and are re-raised as is.
    def redirect_options(redirects, protect_callback)
      redirects = (redirects || {}).dup
      redirects[:limit] ||= 10
      callback = redirects[:callback]
      if protect_callback && callback
        redirects[:callback] = lambda do |*args|
          callback.call(*args)
        rescue StandardError => error
          raise URLPolicy::Failure.new(error)
        end
      end
      redirects
    end

    # Outermost page middleware: each retry gets its own attempt deadline.
    def page_middleware(faraday)
      faraday.request :retry, max: @retries
      faraday.use AttemptTimeout, @attempt_timeout
      # Responses run in reverse order: decompress before applying the charset.
      faraday.response :encoding
      faraday.request :gzip if @max_html_bytes.nil?
    end

    # LimitedResponse wraps the cache and Streaming runs inside it, so cached
    # bodies are checked too and the cache stores the received bytes.
    def page_limit_and_cache_middleware(faraday)
      faraday.use LimitedResponse, @max_html_bytes if @max_html_bytes
      if @cache.is_a?(Hash)
        cache_options = @cache.dup
        cache_options[:serializer] ||= Marshal
        faraday.use Faraday::HttpCache, **cache_options
      end
      faraday.use LimitedResponse::Streaming, @max_html_bytes if @max_html_bytes
    end
  end
end
