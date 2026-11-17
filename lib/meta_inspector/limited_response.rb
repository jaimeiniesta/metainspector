require 'zlib'
require 'stringio'

module MetaInspector
  # Enforces max_html_bytes before charset conversion or parsing. Keep this
  # outside the HTTP cache, and Streaming inside it, so cached bodies are checked
  # too and the cache stores the received bytes rather than an empty stream.
  class LimitedResponse < Faraday::Middleware
    CHUNK_SIZE = 16 * 1024

    def self.check_size!(size, limit)
      return if size <= limit

      raise MetaInspector::ParserError, "HTML response exceeds the limit of #{limit} bytes"
    end

    def initialize(app, limit)
      super(app)
      @limit = limit
    end

    def call(env)
      env.request_headers['Accept-Encoding'] ||= 'gzip,deflate'
      @app.call(env).on_complete do |response|
        body = response.body
        self.class.check_size!(body.bytesize, @limit)
        next if body.empty? || response.status == 206

        encodings = response.response_headers['Content-Encoding'].to_s.split(',').map { |value| value.strip.downcase }
        next if encodings.empty? || encodings.include?('identity')

        encodings.reverse_each do |encoding|
          body = case encoding
                 when 'gzip' then gunzip(body)
                 when 'deflate' then inflate(body)
                 else
                   raise MetaInspector::RequestError, "Unsupported Content-Encoding with max_html_bytes: #{encoding}"
                 end
        end
        response.body = body
        response.response_headers['Content-Length'] = body.bytesize
        response.response_headers.delete('Content-Encoding')
      end
    rescue Zlib::Error => error
      raise MetaInspector::RequestError.new(error)
    end

    private

    def append(body, chunk)
      self.class.check_size!(body.bytesize + chunk.bytesize, @limit)
      body << chunk
    end

    def gunzip(bytes)
      body = ''.b
      io = StringIO.new(bytes)
      # gzip can contain multiple members; apply one budget to all of them.
      until io.eof?
        reader = Zlib::GzipReader.new(io, encoding: Encoding::BINARY)
        begin
          while (chunk = reader.read(CHUNK_SIZE)) && !chunk.empty?
            append(body, chunk)
          end
          unused = reader.unused
        ensure
          reader.finish
        end
        io.pos -= unused.bytesize if unused
      end
      body
    end

    def inflate(bytes, window_bits = Zlib::MAX_WBITS)
      body = ''.b
      inflater = Zlib::Inflate.new(window_bits)
      begin
        # Block form yields bounded chunks instead of allocating the full output.
        inflater.inflate(bytes) { |chunk| append(body, chunk) }
        inflater.finish { |chunk| append(body, chunk) }
      ensure
        inflater.close
      end
      body
    rescue Zlib::DataError
      raise if window_bits < 0

      # Some servers send raw DEFLATE rather than a zlib-wrapped stream.
      inflate(bytes, -Zlib::MAX_WBITS)
    end

    class Streaming < Faraday::Middleware
      def initialize(app, limit)
        super(app)
        @limit = limit
      end

      def call(env)
        body = ''.b
        # Redirects copy the environment but share request options. Each hop
        # needs its own buffer and callback, as do retries and HEAD/GET pairs.
        env.request = env.request.dup
        env.request.on_data = proc do |chunk, _total, _response|
          LimitedResponse.check_size!(body.bytesize + chunk.bytesize, @limit)
          body << chunk.b
        end
        @app.call(env).on_complete do |response|
          # Net::HTTP tags its buffered body with the HTTP charset, including
          # quoted labels. Streaming replaces that body, so retain the tag.
          charset = response.response_headers['Content-Type'].to_s[/(?:\A|;)\s*charset=([^;]+)/i, 1]
          if charset
            charset = charset.strip
            charset = charset[1...-1] if charset.start_with?('"') && charset.end_with?('"')
            begin
              body.force_encoding(charset)
            rescue ArgumentError
              # Unknown charsets are ignored, as in the Net::HTTP adapter.
            end
          end
          response.body = body
        end
      end
    end
  end
end
