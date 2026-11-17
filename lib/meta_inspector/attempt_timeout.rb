require 'timeout'
require 'net/http'
require 'faraday'

module MetaInspector
  # Runs inside the retry middleware, so it applies to each attempt of a page
  # request, redirects included, and every retry gets the full time.
  class AttemptTimeout < Faraday::Middleware
    # Not a Faraday::TimeoutError or Timeout::Error, so the retry middleware
    # doesn't retry it. Request raises it as MetaInspector::TimeoutError.
    class Expired < Faraday::Error; end

    def initialize(app, seconds)
      super(app)
      @seconds = seconds
    end

    # Faraday's timeouts don't fire while a server keeps streaming, so each
    # attempt also has its own deadline. An attempt that reaches it isn't
    # retried: a server that keeps one busy that long would keep the next ones
    # busy too.
    #
    # https://github.com/jaimeiniesta/metainspector/issues/188
    # https://github.com/lostisland/faraday/issues/602
    #
    # The Net::HTTP adapter raises Faraday::ConnectionFailed for a connection
    # timeout, as for a refused connection. Raising Faraday::TimeoutError instead
    # lets the retry middleware retry it, and it reaches the caller as
    # MetaInspector::TimeoutError (#598).
    def call(env)
      Timeout.timeout(@seconds) { @app.call(env) }
    rescue Timeout::Error => error
      raise Expired, error
    rescue Faraday::ConnectionFailed => error
      raise unless error.wrapped_exception.is_a?(Net::OpenTimeout)

      raise Faraday::TimeoutError, error.wrapped_exception
    end
  end
end
