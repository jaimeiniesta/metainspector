module MetaInspector
  # Runs inside redirect handling, before cache access or the network adapter.
  class URLPolicy < Faraday::Middleware
    class InvalidURL < MetaInspector::RequestError; end

    class Failure < StandardError
      attr_reader :original

      def initialize(original)
        @original = original
        super('URL policy failed')
      end
    end

    PAGE_HEADERS = %w[user-agent accept accept-language accept-encoding].freeze
    IMAGE_HEADERS = (PAGE_HEADERS + %w[range]).freeze

    def self.validate!(value)
      uri = URI.parse(value.to_s)
      unless uri.is_a?(URI::HTTP) && uri.hostname && !uri.hostname.empty?
        raise InvalidURL, 'URL must be HTTP or HTTPS'
      end
      uri
    rescue URI::InvalidURIError, URI::InvalidComponentError => error
      raise InvalidURL.new(error)
    end

    def initialize(app, filter, image_origin = nil, request_origin: nil)
      super(app)
      @filter = filter
      @image_origin = image_origin && self.class.validate!(image_origin)
      @request_origin = request_origin && self.class.validate!(request_origin)
      @request_origin ||= @image_origin
      @allowed_headers = @image_origin ? IMAGE_HEADERS : PAGE_HEADERS
    end

    def call(env)
      uri = self.class.validate!(env.url)
      cross_image_origin = @image_origin && origin(uri) != origin(@image_origin)
      if cross_image_origin || (@request_origin && origin(uri) != origin(@request_origin))
        env.request_headers.delete_if { |key, _| !@allowed_headers.include?(key.downcase) }
      end
      if cross_image_origin
        unless @image_origin.scheme == 'https' && uri.scheme == 'http'
          referer = @image_origin.dup
          referer.userinfo = nil
          referer.path = '/'
          referer.query = nil
          referer.fragment = nil
          env.request_headers['Referer'] = referer.to_s
        end
      end
      check_filter(uri) if @filter
      @app.call(env)
    end

    private

    def origin(uri)
      [uri.scheme.downcase, uri.hostname.downcase, uri.port]
    end

    def check_filter(uri)
      # Parsing detaches the strings too: URI#dup alone shares its hostname.
      begin
        allowed = @filter.call(URI.parse(uri.to_s).freeze)
      rescue StandardError => error
        raise Failure.new(error)
      end
      unless allowed
        raise Failure.new(MetaInspector::RequestError.new('Request blocked by url_filter'))
      end
    end
  end
end
