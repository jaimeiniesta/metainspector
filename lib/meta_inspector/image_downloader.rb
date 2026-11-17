require 'stringio'
require 'fastimage'
require 'timeout'
require 'base64'

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

    def metadata(url, reject_invalid_url: false)
      fetch(url, metadata: true, reject_invalid_url: reject_invalid_url)
    end

    def inline_metadata(url)
      header, payload = url.split(',', 2)
      return nil unless payload && !payload.match?(/%(?![0-9a-fA-F]{2})/)

      bytes = payload.gsub(/%([0-9a-fA-F]{2})/) { [$1.to_i(16)].pack('C') }.b
      bytes = Base64.strict_decode64(bytes) if header.match?(/;base64\z/i)
      dimensions = FastImage.size(StringIO.new(bytes))
      return nil unless dimensions

      { dimensions: dimensions, type: FastImage.type(StringIO.new(bytes)), file_size: bytes.bytesize }
    rescue ArgumentError
      nil
    end

    private

    # The first MAX_BYTES bytes of a successful image response. complete is
    # true when the whole body was read.
    Download = Struct.new(:status, :headers, :bytes, :complete, keyword_init: true)
    private_constant :Download

    def fetch(url, metadata:, reject_invalid_url:)
      download = download(url, reject_invalid_url)
      return unless download.status && (200..299).cover?(download.status)

      dimensions = FastImage.size(StringIO.new(download.bytes))
      return dimensions unless metadata

      { dimensions: dimensions, type: FastImage.type(StringIO.new(download.bytes)), file_size: file_size(download) }
    rescue URLPolicy::Failure => failure
      raise failure.original
    rescue URI::InvalidComponentError => error
      raise MetaInspector::RequestError.new(error)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError,
           Faraday::FollowRedirects::RedirectLimitReached, URI::InvalidURIError, Timeout::Error
      nil
    end

    # Streams the response and stops as soon as it has MAX_BYTES, gets an
    # error status, or reaches TIMEOUT.
    def download(url, reject_invalid_url)
      download = Download.new(bytes: ''.b, complete: false)
      received = 0
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
              download.status = env.status
              download.headers = env.response_headers
              remaining = MAX_BYTES - received
              received += chunk.bytesize
              # Count redirect bodies too, across the entire lookup.
              if (200..299).cover?(env.status)
                download.bytes << chunk.b.byteslice(0, remaining)
              elsif !(300..399).cover?(env.status)
                throw stop
              end
              throw stop if received >= MAX_BYTES
            end
          end
          download.complete = true
        end
      end
      download
    end

    # The full size of the image, from Content-Range for partial responses,
    # or from Content-Length or the bytes read for complete ones.
    def file_size(download)
      status, headers = download.status, download.headers
      value = if status == 206
                headers['content-range'].to_s[/\Abytes \d+-\d+\/(\d+)\z/i, 1]
              elsif status == 200 && (headers['content-encoding'].nil? || headers['content-encoding'] == 'identity')
                length = headers['content-length']
                length.nil? && download.complete ? download.bytes.bytesize.to_s : length.to_s[/\A\d+\z/]
              end
      value.to_i if value
    end
  end
end
