module MetaInspector
  # A MetaInspector::Document knows about its URL and its contents
  class Document
    attr_reader :html_content_only, :allow_redirections, :warn_level, :headers

    include MetaInspector::Exceptionable

    # Initializes a new instance of MetaInspector::Document, setting the URL to the one given
    # Options:
    # => connection_timeout: defaults to 20 seconds
    # => read_timeout: defaults to 20 seconds
    # => retries: defaults to 3 times
    # => html_content_type_only: if an exception should be raised if request content-type is not text/html. Defaults to false
    # => allow_redirections: when true, follow HTTP redirects. Defaults to true
    # => document: the html of the url as a string
    # => warn_level: what to do when encountering exceptions. Can be :warn, :raise or nil
    # => headers: object containing custom headers for the request
    def initialize(initial_url, options = {})
      options             = defaults.merge(options)
      @connection_timeout = options[:connection_timeout]
      @read_timeout       = options[:read_timeout]
      @retries            = options[:retries]
      @html_content_only  = options[:html_content_only]
      @allow_redirections = options[:allow_redirections]
      @document           = options[:document]
      @headers            = options[:headers]
      @warn_level         = options[:warn_level]
      @exception_log      = options[:exception_log] || MetaInspector::ExceptionLog.new(warn_level: warn_level)
      @url                = MetaInspector::URL.new(initial_url, exception_log: @exception_log)
      @request            = MetaInspector::Request.new(@url,  allow_redirections: @allow_redirections,
                                                              connection_timeout: @connection_timeout,
                                                              read_timeout:       @read_timeout,
                                                              retries:            @retries,
                                                              exception_log:      @exception_log,
                                                              headers:            @headers) unless @document
      @parser             = MetaInspector::Parser.new(self,  exception_log:      @exception_log)
    end

    extend Forwardable
    def_delegators :@url,     :url, :scheme, :host, :root_url
    def_delegators :@request, :content_type, :response
    def_delegators :@parser,  :parsed, :respond_to?, :title, :description, :links,
                              :images, :image, :feed, :charset, :meta_tags, :meta_tag, :meta, :favicon

    # Returns all document data as a nested Hash
    def to_hash
      {
        'url' => url,
        'title' => title,
        'links' => links.to_hash,
        'images' => images.to_a,
        'charset' => charset,
        'feed' => feed,
        'content_type' => content_type,
        'meta_tags' => meta_tags,
        'favicon' => images.favicon,
        'response' => { 'status'  => response.status,
                        'headers' => response.headers }
      }
    end

    # Returns the contents of the document as a string
    def to_s
      document
    end

    private

    def defaults
      { :timeout => 20,
        :retries => 3,
        :html_content_only => false,
        :warn_level => :raise,
        :headers => {'User-Agent' => "MetaInspector/#{MetaInspector::VERSION} (+https://github.com/jaimeiniesta/metainspector)"},
        :allow_redirections => true
      }
    end

    def document
      @document ||= if html_content_only && content_type != "text/html"
                      raise "The url provided contains #{content_type} content instead of text/html content" and nil
                    else
                      @request.read
                    end
    rescue Exception => e
      @exception_log << e
    end
  end
end
