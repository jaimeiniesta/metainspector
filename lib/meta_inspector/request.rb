require 'faraday'
require 'faraday_middleware'
require 'faraday-cookie_jar'
require 'faraday-http-cache'
require 'faraday/encoding'

module MetaInspector

  # Makes the request to the server
  class Request
    def initialize(initial_url, options = {})
      @url                = initial_url

      fail MetaInspector::RequestError.new('URL must be HTTP') unless @url.url =~ /http[s]?:\/\//i

      @allow_redirections = options[:allow_redirections]
      @connection_timeout = options[:connection_timeout]
      @read_timeout       = options[:read_timeout]
      @retries            = options[:retries]
      @headers            = options[:headers]
      @faraday_options    = options[:faraday_options] || {}
      @faraday_http_cache = options[:faraday_http_cache]

      response            # request early so we can fail early
    end

    extend Forwardable
    delegate :url => :@url

    def read
      response.body if response
    end

    def content_type
      return nil if response.headers['content-type'].nil?
      response.headers['content-type'].split(';')[0] if response
    end

    def response
      @response ||= fetch
    rescue Faraday::TimeoutError => e
      raise MetaInspector::TimeoutError.new(e)
    rescue Faraday::Error::ConnectionFailed, Faraday::SSLError, URI::InvalidURIError, FaradayMiddleware::RedirectLimitReached => e
      raise MetaInspector::RequestError.new(e)
    end

    private

    def fetch
      @faraday_options.merge!(:url => url)

      session = Faraday.new(@faraday_options) do |faraday|
        faraday.request :retry, max: @retries

        if @allow_redirections
          faraday.use FaradayMiddleware::FollowRedirects, limit: 10
          faraday.use :cookie_jar
        end

        if @faraday_http_cache.is_a?(Hash)
          @faraday_http_cache[:serializer] ||= Marshal
          faraday.use Faraday::HttpCache, @faraday_http_cache
        end

        faraday.headers.merge!(@headers || {})
        faraday.response :encoding
        faraday.adapter :net_http
      end

      response = session.get do |req|
        req.options.timeout      = @connection_timeout
        req.options.open_timeout = @read_timeout
      end

      @url.url = response.env.url.to_s

      response
    end
  end
end
