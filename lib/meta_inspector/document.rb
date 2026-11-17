module MetaInspector
  # A MetaInspector::Document knows about its URL and its contents
  class Document
    attr_reader :allow_non_html_content, :allow_redirections, :headers

    # Initializes a new instance of MetaInspector::Document, setting the URL
    # Options:
    # * connection_timeout: defaults to 20 seconds
    # * read_timeout: defaults to 20 seconds
    # * retries: defaults to 3 times
    # * allow_redirections: when true, follow HTTP redirects. Defaults to true
    # * head_first: check content type with HEAD before GET. Defaults to false
    # * document: the html of the url as a string
    # * headers: object containing custom headers for the request
    # * normalize_url: true by default
    # * download_images: fetch missing image dimensions. Defaults to true
    # * max_image_downloads: maximum image size lookups. Defaults to 20; nil for unlimited
    # * download_image_options: supports reject_invalid_images (default false)
    # * inline_image_data: return full data URLs in image results (default false)
    # * fetch_all_image_meta: enable image validity metadata (default false)
    # * max_html_bytes: maximum received, decompressed and parsed HTML bytes, or nil for unlimited
    # * url_filter: callable receiving a URI before each request; false/nil rejects it
    # * faraday_options: an optional hash of options to pass to Faraday on the request.
    #   Its faraday_http_cache key configures response caching with Faraday::HttpCache
    #
    # Raises ArgumentError for any other key, including String keys
    OPTIONS = %i[
      connection_timeout read_timeout retries encoding allow_redirections allow_non_html_content
      head_first document headers normalize_url download_images max_image_downloads
      download_image_options fetch_all_image_meta inline_image_data max_html_bytes url_filter
      faraday_options
    ].freeze

    # Options used by Request and by Parser. HttpSession and ImageDownloader
    # pick their own options from the whole hash.
    REQUEST_OPTIONS = %i[
      allow_redirections head_first allow_non_html_content connection_timeout read_timeout encoding
    ].freeze
    PARSER_OPTIONS = %i[
      download_images max_html_bytes max_image_downloads download_image_options fetch_all_image_meta
      inline_image_data
    ].freeze
    private_constant :REQUEST_OPTIONS, :PARSER_OPTIONS

    def initialize(initial_url, options = {})
      validate_option_keys!(options)
      options = defaults.merge(options)
      validate_limit!(options, :max_html_bytes)
      validate_limit!(options, :max_image_downloads)

      @allow_redirections     = options[:allow_redirections]
      @allow_non_html_content = options[:allow_non_html_content]
      @headers                = options[:headers]
      @document               = options[:document]

      http_session = HttpSession.new(options)
      @url         = URL.new(initial_url, normalize: options[:normalize_url])
      @request     = Request.new(@url, http_session: http_session, **options.slice(*REQUEST_OPTIONS)) unless @document
      @parser      = Parser.new(self, image_downloader: ImageDownloader.new(http_session, @url, options),
                                      **options.slice(*PARSER_OPTIONS))
    end

    extend Forwardable
    delegate %i[url scheme host root_url tracked? untracked_url untrack!] => :@url

    # No request is made when the HTML is passed with the document: option,
    # so these return nil in that case
    def content_type
      @request&.content_type
    end

    def response
      @request&.response
    end

    delegate %i[
      parsed language title best_title author best_author h1 h2 h3 h4 h5 h6 description best_description
      links images iframes iframe_sources feeds charset meta_tags meta_tag meta head_links stylesheets canonicals
    ] => :@parser

    # Returns all document data as a nested Hash
    def to_hash
      {
        'url'              => url,
        'scheme'           => scheme,
        'host'             => host,
        'root_url'         => root_url,
        'language'         => language,
        'title'            => title,
        'best_title'       => best_title,
        'author'           => author,
        'best_author'      => best_author,
        'description'      => description,
        'best_description' => best_description,
        'h1'               => h1,
        'h2'               => h2,
        'h3'               => h3,
        'h4'               => h4,
        'h5'               => h5,
        'h6'               => h6,
        'links'            => links.to_hash,
        'images'           => images.to_a,
        'iframes'          => iframes,
        'charset'          => charset,
        'feeds'            => feeds,
        'content_type'     => content_type,
        'meta_tags'        => meta_tags,
        'favicon'          => images.favicon,
        'response'         => response && { 'status'  => response.status,
                                            'headers' => serialized_response_headers }
      }
    end

    # Returns the contents of the document as a string
    def to_s
      document
    end

    private

    # An option that is misspelled, or given with a String key (as when read from
    # JSON or YAML), would otherwise be ignored: with 'document' => html, the page
    # would be fetched instead of parsing the HTML.
    def validate_option_keys!(options)
      unknown = options.keys - OPTIONS
      return if unknown.empty?

      message = "Unknown option#{'s' if unknown.size > 1}: #{unknown.map(&:inspect).join(', ')}"
      message += ' (option keys must be Symbols)' if unknown.any?(String)
      if unknown.include?(:faraday_http_cache)
        message += ' (pass it inside faraday_options: { faraday_http_cache: ... })'
      end
      raise ArgumentError, message
    end

    def validate_limit!(options, name)
      value = options[name]
      return if value.nil? || (value.is_a?(Integer) && value >= 0)

      raise ArgumentError, "#{name} must be a non-negative Integer or nil"
    end

    # Middleware can add headers that Net::HTTP would have normalized: faraday-gzip
    # sets "Content-Length" to an Integer after decompressing. Downcase the names
    # and re-encode only String values.
    def serialized_response_headers
      response.headers.to_h do |name, value|
        [name.to_s.downcase, value.is_a?(String) ? utf8_header_value(value) : value]
      end
    end

    # Net::HTTP returns binary strings, even when the bytes are valid UTF-8.
    def utf8_header_value(value)
      source_encoding = value.encoding == Encoding::BINARY ? Encoding::UTF_8 : value.encoding
      value.encode(Encoding::UTF_8, source_encoding, invalid: :replace, undef: :replace)
    end

    def defaults
      {
        connection_timeout:     20,
        read_timeout:           20,
        retries:                3,
        headers:                { 'User-Agent' => default_user_agent, 'Accept-Encoding' => 'identity' },
        allow_redirections:     true,
        allow_non_html_content: false,
        head_first:             false,
        normalize_url:          true,
        download_images:        true,
        max_image_downloads:    20
      }
    end

    def default_user_agent
      "MetaInspector/#{MetaInspector::VERSION} (+https://github.com/jaimeiniesta/metainspector)"
    end

    def document
      @document ||= begin
        unless allow_non_html_content || Request.html_content_type?(content_type)
          raise NonHtmlError.for(content_type)
        end
        @request.read
      end
    end
  end
end
