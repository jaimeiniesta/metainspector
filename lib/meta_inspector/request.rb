require_relative 'http_session'
require_relative 'html_encoding'

module MetaInspector

  # Makes the request to the server
  class Request
    def initialize(initial_url, options = {})
      @url                = initial_url

      URLPolicy.validate!(@url.url)

      @allow_redirections = options[:allow_redirections]
      @head_first         = options[:head_first]
      @allow_non_html_content = options[:allow_non_html_content]
      @connection_timeout = options[:connection_timeout]
      @read_timeout       = options[:read_timeout]
      @encoding           = options[:encoding]
      @http_session       = options[:http_session] || HttpSession.new(options)

      response            # request early so we can fail early
    end

    extend Forwardable
    delegate :url => :@url

    def read
      return unless response
      body = response.body
      check_content_encoding!(body)
      if body.encoding == Encoding::BINARY
        # The adapter tags the body only with HTTP charsets Ruby knows.
        label = response.headers['content-type'].to_s[/(?:\A|;)\s*charset\s*=\s*["']?([^;\s"']+)/i, 1]
        charset = HtmlEncoding.resolve(label)
        body = body.dup.force_encoding(charset) if charset
      end
      body = body.dup.force_encoding(@encoding) if @encoding
      encoding = HtmlEncoding.byte_order_mark_encoding(body)
      body = body.dup.force_encoding(encoding) if encoding && !Encoding.find(encoding).ascii_compatible?
      body = HtmlEncoding.normalize(body)
      # Replace invalid bytes with U+FFFD, as browsers do, so one bad byte
      # doesn't make the whole page fail. Binary bodies are decoded later by the parser.
      body = if body.encoding.ascii_compatible?
               body.scrub
             else
               body.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
             end
      body.tr("\000", '')
    rescue ArgumentError, EncodingError => e
      raise MetaInspector::RequestError.new(e)
    end

    def content_type
      response_content_type(response)
    end

    def response
      @response ||= fetch
    rescue URLPolicy::Failure => failure
      raise failure.original
    rescue Faraday::TimeoutError, AttemptTimeout::Expired => e
      raise MetaInspector::TimeoutError.new(e)
    rescue Faraday::ConnectionFailed, Faraday::SSLError, URI::InvalidURIError, URI::InvalidComponentError,
           Faraday::FollowRedirects::RedirectLimitReached, Zlib::Error => e
      raise MetaInspector::RequestError.new(e)
    end

    private

    def fetch
      session = @http_session.build(url)

      check_head_content_type(session) if @head_first
      response = perform_request(session, :get)

      if @allow_redirections
        @url.url = response.env.url.to_s
      end

      response
    end

    def check_head_content_type(session)
      head_response = perform_request(session, :head)
      return unless head_response.success?

      type = response_content_type(head_response)
      if !@allow_non_html_content && !type.nil? && type != 'text/html'
        fail MetaInspector::NonHtmlError.new "The url provided contains #{type} content instead of text/html content"
      end
    end

    # The compression middleware removes Content-Encoding once it has decoded the
    # body. If it's still there, the body is compressed bytes, not HTML (#597).
    def check_content_encoding!(body)
      return if body.empty?

      header = response.headers['content-encoding'].to_s
      encodings = header.split(',').map { |value| value.strip.downcase }.reject(&:empty?) - ['identity']
      return if encodings.empty?

      raise MetaInspector::RequestError, "Unsupported Content-Encoding: #{header.strip}"
    end

    def response_content_type(response)
      response.headers['content-type']&.split(';')&.first&.strip&.downcase
    end

    def perform_request(session, method)
      session.public_send(method) do |req|
        req.options.open_timeout = @connection_timeout
        req.options.timeout      = @read_timeout
      end
    end
  end
end
