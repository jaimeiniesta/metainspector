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
      fetch(url, metadata: false, reject_invalid_url: reject_invalid_url)
    end

    def metadata(url)
      fetch(url, metadata: true, reject_invalid_url: false)
    end

    private

    def fetch(url, metadata:, reject_invalid_url:)
      bytes = ''.b
      received = 0
      status = nil
      headers = nil
      completed = false
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
              headers = env.response_headers
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
          completed = true
        end
      end
      return unless status && (200..299).cover?(status)

      dimensions = FastImage.size(StringIO.new(bytes))
      return dimensions unless metadata

      { dimensions: dimensions, type: FastImage.type(StringIO.new(bytes)),
        file_size: file_size(status, headers, completed, bytes.bytesize) }
    rescue URLPolicy::Failure => failure
      raise failure.original
    rescue URLPolicy::InvalidURL
      raise unless reject_invalid_url

      nil
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError,
           Faraday::FollowRedirects::RedirectLimitReached, URI::InvalidURIError, Timeout::Error
      nil
    end

    def file_size(status, headers, completed, bytesize)
      value = if status == 206
                headers['content-range'].to_s[/\Abytes \d+-\d+\/(\d+)\z/i, 1]
              elsif status == 200 && (headers['content-encoding'].nil? || headers['content-encoding'] == 'identity')
                length = headers['content-length']
                length.nil? && completed ? bytesize.to_s : length.to_s[/\A\d+\z/]
              end
      value.to_i if value
    end
  end
end
