require 'nokogiri'

module MetaInspector
  ##
  # Parses the document with Nokogiri.
  #
  # Delegates the parsing of the different elements to specialized parsers,
  # passing itself as a reference for coordination purposes
  #
  class Parser
    include MetaInspector::Exceptionable

    def initialize(document, options = {})
      @document        = document
      @exception_log   = options[:exception_log]
      @meta_tag_parser = MetaInspector::Parsers::MetaTagsParser.new(self)
      @links_parser    = MetaInspector::Parsers::LinksParser.new(self)
      @download_images = options[:download_images]
      @images_parser   = MetaInspector::Parsers::ImagesParser.new(self, download_images: @download_images)
      @texts_parser    = MetaInspector::Parsers::TextsParser.new(self)
    end

    extend Forwardable
    delegate [:url, :scheme, :host]                              => :@document
    delegate [:meta_tags, :meta_tag, :meta, :charset, :language] => :@meta_tag_parser
    delegate [:links, :feed, :base_url]                          => :@links_parser
    delegate :images                                             => :@images_parser
    delegate [:title, :best_title, :description]                 => :@texts_parser

    # Returns the whole parsed document
    def parsed
      @parsed ||= Nokogiri::HTML(@document.to_s)
    rescue Exception => e
      @exception_log << e
    end
  end
end
