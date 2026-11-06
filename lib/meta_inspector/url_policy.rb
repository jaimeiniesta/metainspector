module MetaInspector
  # Runs inside redirect handling, before cache access or the network adapter.
  class URLPolicy < Faraday::Middleware
    class Failure < StandardError
      attr_reader :original

      def initialize(original)
        @original = original
        super('URL policy failed')
      end
    end

    IMAGE_HEADERS = %w[user-agent accept accept-language accept-encoding range].freeze

    def self.validate!(value)
      uri = URI.parse(value.to_s)
      unless uri.is_a?(URI::HTTP) && uri.hostname && !uri.hostname.empty?
        raise MetaInspector::RequestError, 'URL must be HTTP or HTTPS'
      end
      uri
    rescue URI::InvalidURIError => error
      raise MetaInspector::RequestError.new(error)
    end

    def initialize(app, filter, image_origin = nil)
      super(app)
      @filter = filter
      @image_origin = image_origin && self.class.validate!(image_origin)
    end

    def call(env)
      uri = self.class.validate!(env.url)
      if @image_origin && origin(uri) != origin(@image_origin)
        env.request_headers.delete_if { |key, _| !IMAGE_HEADERS.include?(key.downcase) }
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
