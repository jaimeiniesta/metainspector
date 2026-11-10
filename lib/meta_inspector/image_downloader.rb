require 'stringio'
require 'fastimage'
require 'timeout'

module MetaInspector
  class ImageDownloader
    MAX_BYTES = 256 * 1024
    TIMEOUT = 2

    def initialize(session, origin, options = {})
      @session = session
      @origin = origin
      @connection_timeout = [options[:connection_timeout] || TIMEOUT, TIMEOUT].min
      @read_timeout = [options[:read_timeout] || TIMEOUT, TIMEOUT].min
    end

    def size(url, reject_invalid_url: false)
      bytes = ''.b
      received = 0
      status = nil
      stop = Object.new
      Timeout.timeout(TIMEOUT) do
        session = @session.build(url, image: true, origin: @origin.url, protect_redirect_callback: reject_invalid_url)
        catch(stop) do
          session.get do |request|
            request.headers['Range'] = "bytes=0-#{MAX_BYTES - 1}"
            request.headers['Accept-Encoding'] = 'identity'
            request.options.open_timeout = @connection_timeout
            request.options.timeout = @read_timeout
            request.options.on_data = proc do |chunk, _total, env|
              status = env.status
              remaining = MAX_BYTES - received
              received += chunk.bytesize
              # Count redirect bodies too, across the entire lookup.
              if (200..299).cover?(status)
                bytes << chunk.b.byteslice(0, remaining)
              elsif !(300..399).cover?(status)
                throw stop
              end
              throw stop if received >= MAX_BYTES
            end
          end
        end
      end
      FastImage.size(StringIO.new(bytes)) if status && (200..299).cover?(status)
    rescue URLPolicy::Failure => failure
      raise failure.original
    rescue URLPolicy::InvalidURL
      raise unless reject_invalid_url

      nil
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError,
           Faraday::FollowRedirects::RedirectLimitReached, URI::InvalidURIError, Timeout::Error
      nil
    end
  end
end
