require 'http/cookie'
require 'faraday'
require 'faraday-cookie_jar'
require 'faraday-http-cache'
require 'faraday/encoding'
require 'faraday/follow_redirects'
require 'faraday/gzip'
require 'faraday/retry'
require 'timeout'

module MetaInspector

  # Makes the request to the server
  class Request
    def initialize(initial_url, options = {})
      @url                = initial_url

      fail MetaInspector::RequestError.new('URL must be HTTP') unless @url.url =~ /http[s]?:\/\//i

      @allow_redirections = options[:allow_redirections]
      @head_first         = options[:head_first]
      @allow_non_html_content = options[:allow_non_html_content]
      @connection_timeout = options[:connection_timeout]
      @read_timeout       = options[:read_timeout]
      @retries            = options[:retries]
      @encoding           = options[:encoding]
      @headers            = options[:headers]
      @faraday_http_cache = faraday_http_cache_option(options)
      # faraday_http_cache configures our middleware, so it must not reach Faraday.new
      @faraday_options    = (options[:faraday_options] || {}).except(:faraday_http_cache)

      response            # request early so we can fail early
    end

    extend Forwardable
    delegate :url => :@url

    def read
      return unless response
      body = response.body
      body = body.encode!(@encoding, @encoding, :invalid => :replace) if @encoding
      body.tr("\000", '')
    rescue ArgumentError => e
      raise MetaInspector::RequestError.new(e)
    end

    def content_type
      response_content_type(response)
    end

    def response
      @response ||= fetch
    rescue Faraday::TimeoutError => e
      raise MetaInspector::TimeoutError.new(e)
    rescue Faraday::ConnectionFailed, Faraday::SSLError, URI::InvalidURIError, Faraday::FollowRedirects::RedirectLimitReached => e
      raise MetaInspector::RequestError.new(e)
    end

    private

    # faraday_http_cache goes inside faraday_options. The top-level option still works, but is deprecated.
    def faraday_http_cache_option(options)
      nested    = (options[:faraday_options] || {})[:faraday_http_cache]
      top_level = options[:faraday_http_cache]
      return nested if top_level.nil?

      unless nested.nil?
        fail ArgumentError, 'Pass faraday_http_cache inside faraday_options or as a top-level option, not both'
      end

      self.class.warn_faraday_http_cache_deprecation
      top_level
    end

    # Once per process: apps fetch many pages with the same options, and a warning
    # per request would flood their logs
    def self.warn_faraday_http_cache_deprecation
      return if @faraday_http_cache_deprecation_warned

      @faraday_http_cache_deprecation_warned = true
      warn 'DEPRECATION WARNING: the top-level faraday_http_cache option is deprecated and will be removed ' \
           'in the next major version. Pass it inside faraday_options instead: ' \
           'faraday_options: { faraday_http_cache: { store: cache } }'
    end

    def fetch
      Timeout::timeout(fatal_timeout) do
        # Work on copies: the caller may reuse or freeze the hashes it passed in, and
        # losing :redirect would drop a callback that blocks redirects to private hosts
        faraday_options          = @faraday_options.merge(:url => url)
        follow_redirects_options = (faraday_options.delete(:redirect) || {}).dup

        session = Faraday.new(faraday_options) do |faraday|
          faraday.request :retry, max: @retries

          faraday.request :gzip

          if @allow_redirections
            follow_redirects_options[:limit] ||= 10
            faraday.use Faraday::FollowRedirects::Middleware, **follow_redirects_options
            faraday.use :cookie_jar
          end

          if @faraday_http_cache.is_a?(Hash)
            cache_options = @faraday_http_cache.dup
            cache_options[:serializer] ||= Marshal
            faraday.use Faraday::HttpCache, **cache_options
          end

          faraday.headers.merge!(@headers || {})
          faraday.response :encoding
          faraday.adapter :net_http
        end

        check_head_content_type(session) if @head_first
        response = perform_request(session, :get)

        if @allow_redirections
          @url.url = response.env.url.to_s
        end

        response
      end
    rescue Timeout::Error => e
      raise MetaInspector::TimeoutError.new(e)
    end

    def check_head_content_type(session)
      head_response = perform_request(session, :head)
      return unless head_response.success?

      type = response_content_type(head_response)
      if !@allow_non_html_content && !type.nil? && type != 'text/html'
        fail MetaInspector::NonHtmlError.new "The url provided contains #{type} content instead of text/html content"
      end
    end

    def response_content_type(response)
      response.headers['content-type']&.split(';')&.first
    end

    def perform_request(session, method)
      session.public_send(method) do |req|
        req.options.timeout      = @connection_timeout
        req.options.open_timeout = @read_timeout
      end
    end

    # Timeouts when connecting / reading a request are handled by Faraday, but in the
    # case of URLs that respond with streaming, Faraday will never return. In that case,
    # we'll resort to our own timeout
    #
    # https://github.com/jaimeiniesta/metainspector/issues/188
    # https://github.com/lostisland/faraday/issues/602
    #
    def fatal_timeout
      (@connection_timeout || 0) + (@read_timeout || 0) + 1
    end
  end
end
