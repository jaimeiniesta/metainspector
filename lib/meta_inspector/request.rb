# -*- encoding: utf-8 -*-

require 'open-uri'
require 'open_uri_redirections'
require 'timeout'

module MetaInspector

  # Makes the request to the server
  class Request
    include MetaInspector::Exceptionable

    def initialize(initial_url, options = {})
      options = defaults.merge(options)

      @url                = initial_url
      @allow_redirections = options[:allow_redirections] || false
      @timeout            = options[:timeout]
      @exception_log      = options[:exception_log]
      @headers            = options[:headers] || {}

      response            # as soon as it is set up, we make the request so we can fail early
    end

    extend Forwardable
    def_delegators :@url, :url

    def read
      response.body if response
    end

    def content_type
      response.content_type if response
    end

    private

    def response
      Timeout::timeout(@timeout) { @fetch ||= fetch }
    rescue TimeoutError, SocketError, RuntimeError => e
      @exception_log << e
      nil
    end

    def fetch
      options = {
        :allow_redirections => @allow_redirections,
        :headers => @headers
      }

      request = MetaInspector::GETRequestAdapter.new(url, options)

      @url.url = request.url

      request
    end

    def defaults
      { timeout: 20, exception_log: MetaInspector::ExceptionLog.new }
    end

    class OpenURIGetRequest
      def initialize(url, options)
        client_options = {}
        client_options[:allow_redirections] = options[:allow_redirections]
        client_options.merge! options[:headers]
        @response = open(url, client_options)
      end

      def url
        @response.base_uri.to_s
      end

      def body
        @response.read
      end

      def content_type
        @response.content_type
      end
    end

    class TyphoeusGetRequest
      def initialize(url, options)
        options.merge!(:accept_encoding => "deflate, gzip")
        if options.delete(:allow_redirections)
          cookies = StringIO.new
          options.merge!(:followlocation => true, cookiejar: cookies, cookiefile: cookies)
        end
        @response = Typhoeus.get(url, options)
      end

      def url
        @response.effective_url
      end

      def body
        @response.body
      end

      def content_type
        @response.headers["Content-Type"].split(";")[0]
      end
    end
  end
end
