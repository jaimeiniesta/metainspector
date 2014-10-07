# -*- encoding: utf-8 -*-

require 'faraday'
require 'faraday_middleware'
require 'faraday-cookie_jar'
require 'timeout'

module MetaInspector

  # Makes the request to the server
  class Request
    include MetaInspector::Exceptionable

    def initialize(initial_url, options = {})
      @url                = initial_url
      
      @allow_redirections = options[:allow_redirections]
      @timeout            = options[:timeout]
      @retries            = options[:retries]
      @exception_log      = options[:exception_log]
      @headers            = options[:headers]

      response            # as soon as it is set up, we make the request so we can fail early
    end

    extend Forwardable
    def_delegators :@url, :url

    def read
      response.body if response
    end

    def content_type
      response.headers["content-type"].split(";")[0] if response
    end

    private

    def response
      request_count ||= 0
      request_count += 1
      Timeout::timeout(@timeout) { @response ||= fetch }
    rescue Timeout::Error
      retry unless @retries == request_count
      @exception_log << TimeoutError.new("Attempt to fetch #{url} timed out 3 times.")
    rescue Faraday::ConnectionFailed, RuntimeError => e
      @exception_log << e
      nil
    end

    def fetch
      session = Faraday.new(:url => url) do |faraday|
        if @allow_redirections
          faraday.use FaradayMiddleware::FollowRedirects, limit: 10
          faraday.use :cookie_jar
        end
        faraday.headers.merge!(@headers || {})
        faraday.adapter :net_http
      end
      response = session.get

      @url.url = response.env.url.to_s

      response
    end

    class TimeoutError < StandardError
    end
  end
end
