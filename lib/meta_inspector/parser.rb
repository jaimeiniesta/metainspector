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
      @images_parser   = MetaInspector::Parsers::ImagesParser.new(self)
      @texts_parser    = MetaInspector::Parsers::TextsParser.new(self)
    end

    extend Forwardable
    def_delegators :@document,        :url, :scheme, :host
    def_delegators :@meta_tag_parser, :meta_tags, :meta_tag, :meta, :charset
    def_delegators :@links_parser,    :links, :feed, :base_url
    def_delegators :@images_parser,   :images, :image, :favicon
    def_delegators :@texts_parser,    :title, :description

    # Returns the whole parsed document
    def parsed
      @parsed ||= Nokogiri::HTML(@document.to_s)
    rescue Exception => e
      @exception_log << e
    end
  end
end
