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
    # * max_image_downloads: maximum image size lookups, or nil for unlimited
    # * download_image_options: supports reject_invalid_images (default false)
    # * fetch_all_image_meta: enable image validity metadata (default false)
    # * url_filter: callable receiving a URI before each request; false/nil rejects it
    # * faraday_options: an optional hash of options to pass to Faraday on the request.
    #   Its faraday_http_cache key configures response caching with Faraday::HttpCache
    # * faraday_http_cache: deprecated, use faraday_options: { faraday_http_cache: ... }
    def initialize(initial_url, options = {})
      options             = defaults.merge(options)
      @max_image_downloads = options[:max_image_downloads]
      unless @max_image_downloads.nil? || (@max_image_downloads.is_a?(Integer) && @max_image_downloads >= 0)
        raise ArgumentError, 'max_image_downloads must be a non-negative Integer or nil'
      end

      @connection_timeout = options[:connection_timeout]
      @read_timeout       = options[:read_timeout]
      @retries            = options[:retries]
      @encoding           = options[:encoding]

      @allow_redirections     = options[:allow_redirections]
      @allow_non_html_content = options[:allow_non_html_content]

      @document           = options[:document]
      @download_images    = options[:download_images]
      @headers            = options[:headers]
      @normalize_url      = options[:normalize_url]
      @faraday_options    = options[:faraday_options]
      @faraday_http_cache = options[:faraday_http_cache]
      @http_session       = MetaInspector::HttpSession.new(options)
      @url                = MetaInspector::URL.new(initial_url, normalize:          @normalize_url)
      @request            = MetaInspector::Request.new(@url,    http_session: @http_session,
                                                                allow_redirections: @allow_redirections,
                                                                head_first:         options[:head_first],
                                                                allow_non_html_content: @allow_non_html_content,
                                                                connection_timeout: @connection_timeout,
                                                                read_timeout:       @read_timeout,
                                                                retries:            @retries,
                                                                encoding:           @encoding,
                                                                headers:            @headers,
                                                                faraday_options:    @faraday_options,
                                                                faraday_http_cache: @faraday_http_cache) unless @document
      @parser             = MetaInspector::Parser.new(self,     download_images:    @download_images,
                                                                max_image_downloads: @max_image_downloads,
                                                                download_image_options: options[:download_image_options],
                                                                fetch_all_image_meta: options[:fetch_all_image_meta],
                                                                image_downloader: MetaInspector::ImageDownloader.new(@http_session, @url, options))
    end

    extend Forwardable
    delegate [:url, :scheme, :host, :root_url,
              :tracked?, :untracked_url, :untrack!]   => :@url

    delegate [:content_type, :response]               => :@request

    delegate [:parsed, :language, :title, :best_title, :author, :best_author,
              :h1, :h2, :h3, :h4, :h5, :h6, :description, :best_description, :links,
              :images, :iframes, :iframe_sources, :feeds, :feed, :charset, :meta_tags,
              :meta_tag, :meta, :favicon,
              :head_links, :stylesheets, :canonicals] => :@parser

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
        'response'         => { 'status'  => response.status,
                                'headers' => response.headers }
      }
    end

    # Returns the contents of the document as a string
    def to_s
      document
    end

    private

    def defaults
      { :connection_timeout     => 20,
        :read_timeout           => 20,
        :retries                => 3,
        :headers                => {
                                     'User-Agent'      => default_user_agent,
                                     'Accept-Encoding' => 'identity'
                                  },
        :allow_redirections     => true,
        :allow_non_html_content => false,
        :head_first             => false,
        :normalize_url          => true,
        :download_images        => true,
        :max_image_downloads    => nil }
    end

    def default_user_agent
      "MetaInspector/#{MetaInspector::VERSION} (+https://github.com/jaimeiniesta/metainspector)"
    end

    def document
      @document ||= if !allow_non_html_content && !content_type.nil? && content_type != 'text/html'
        fail MetaInspector::NonHtmlError.new "The url provided contains #{content_type} content instead of text/html content"
      else
        @request.read
      end
    end
  end
end
