# -*- encoding: utf-8 -*-

require 'timeout'
require 'faraday'
require 'faraday_middleware'

module MetaInspector

  # Makes the request to the server
  class Request
    include MetaInspector::Exceptionable

    def initialize(initial_url, options = {})
      options = defaults.merge(options)

      @url                = initial_url
      
      @allow_redirections = case options[:allow_redirections]
        when nil, true
          true
        when false
          false
        else
          raise ArgumentError, "invalid option for allow_redirections. must be true or false"
        end
      
      @timeout            = options[:timeout]
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
      Timeout::timeout(@timeout) { @response ||= fetch }
    rescue TimeoutError, Faraday::ConnectionFailed, RuntimeError => e
      @exception_log << e
      nil
    end

    def fetch
      session = Faraday.new(:url => url) do |faraday|
        if @allow_redirections
          faraday.use FaradayMiddleware::FollowRedirects, limit: 10
        end
        faraday.headers.merge!(@headers || {})
        faraday.adapter :net_http
      end
      response = session.get

      @url.url = response.env.url.to_s

      response
    end

    def defaults
      { timeout: 20, exception_log: MetaInspector::ExceptionLog.new }
    end
  end
end
