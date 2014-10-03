# -*- encoding: utf-8 -*-

module MetaInspector
  # A MetaInspector::Document knows about its URL and its contents
  class Document
    attr_reader :timeout, :html_content_only, :allow_redirections, :warn_level, :headers

    include MetaInspector::Exceptionable

    # Initializes a new instance of MetaInspector::Document, setting the URL to the one given
    # Options:
    # => timeout: defaults to 20 seconds
    # => html_content_type_only: if an exception should be raised if request content-type is not text/html. Defaults to false
    # => allow_redirections: when true, follow HTTP redirects. Defaults to true
    # => document: the html of the url as a string
    # => warn_level: what to do when encountering exceptions. Can be :warn, :raise or nil
    # => headers: object containing custom headers for the request
    def initialize(initial_url, options = {})
      options             = defaults.merge(options)
      @timeout            = options[:timeout]
      @html_content_only  = options[:html_content_only]
      @allow_redirections = options[:allow_redirections]
      @document           = options[:document]
      @headers            = options[:headers]
      @warn_level         = options[:warn_level]
      @exception_log      = options[:exception_log] || MetaInspector::ExceptionLog.new(warn_level: warn_level)
      @url                = MetaInspector::URL.new(initial_url, exception_log: @exception_log)
      @request            = MetaInspector::Request.new(@url,  allow_redirections: @allow_redirections,
                                                              timeout:            @timeout,
                                                              exception_log:      @exception_log,
                                                              headers:            @headers) unless @document
      @parser             = MetaInspector::Parser.new(self,  exception_log:      @exception_log)
    end

    extend Forwardable
    def_delegators :@url,     :url, :scheme, :host, :root_url
    def_delegators :@request, :content_type
    def_delegators :@parser,  :parsed, :respond_to?, :title, :description, :links, :internal_links, :external_links,
                              :images, :image, :feed, :charset, :meta_tags, :meta_tag, :meta, :favicon

    # Returns all document data as a nested Hash
    def to_hash
      {
        'url' => url,
        'title' => title,
        'links' => links,
        'internal_links' => internal_links,
        'external_links' => external_links,
        'images' => images,
        'charset' => charset,
        'feed' => feed,
        'content_type' => content_type,
        'meta_tags' => meta_tags,
        'favicon' => favicon
      }
    end

    # Returns the contents of the document as a string
    def to_s
      document
    end

    private

    def defaults
      { :timeout => 20,
        :html_content_only => false,
        :warn_level => :raise,
        :headers => {'User-Agent' => "MetaInspector/#{MetaInspector::VERSION} (+https://github.com/jaimeiniesta/metainspector)"}
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
