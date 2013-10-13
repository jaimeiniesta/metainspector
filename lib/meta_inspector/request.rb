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
      @allow_redirections = options[:allow_redirections]
      @timeout            = options[:timeout]
      @exception_log      = options[:exception_log]
    end

    extend Forwardable
    def_delegators :@url, :url

    def read
      response.read if response
    end

    def content_type
      response.content_type if response
    end

    private

    def response
      Timeout::timeout(@timeout) { @response ||= open(url, { allow_redirections: @allow_redirections }) }

      rescue TimeoutError, SocketError => e
        @exception_log << e
        nil
    end

    def defaults
      { allow_redirections: false, timeout: 20, exception_log: MetaInspector::ExceptionLog.new }
    end
  end
end
