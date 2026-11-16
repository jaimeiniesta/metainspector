require 'nokogiri'
require_relative 'html_encoding'

module MetaInspector
  ##
  # Parses the document with Nokogiri.
  #
  # Delegates the parsing of the different elements to specialized parsers,
  # passing itself as a reference for coordination purposes
  #
  class Parser
    def initialize(document, options = {})
      @document        = document
      @max_html_bytes  = options[:max_html_bytes]
      @head_links_parser = MetaInspector::Parsers::HeadLinksParser.new(self)
      @meta_tag_parser = MetaInspector::Parsers::MetaTagsParser.new(self)
      @links_parser    = MetaInspector::Parsers::LinksParser.new(self)
      @download_images = options[:download_images]
      @images_parser   = MetaInspector::Parsers::ImagesParser.new(self, download_images: @download_images,
                                                                      max_image_downloads: options[:max_image_downloads],
                                                                      download_image_options: options[:download_image_options],
                                                                      fetch_all_image_meta: options[:fetch_all_image_meta],
                                                                      inline_image_data: options[:inline_image_data],
                                                                      image_downloader: options[:image_downloader])
      @iframes_parser  = MetaInspector::Parsers::IframesParser.new(self)
      @texts_parser    = MetaInspector::Parsers::TextsParser.new(self)

      parsed           # parse early so we can fail early
    end

    extend Forwardable
    delegate [:url, :scheme, :host]                                                        => :@document
    delegate [:meta_tags, :meta_tag, :meta, :charset]                                      => :@meta_tag_parser
    delegate [:head_links, :stylesheets, :canonicals, :feeds, :feed]                       => :@head_links_parser
    delegate [:links, :base_url]                                                           => :@links_parser
    delegate :images                                                                       => :@images_parser
    delegate [:iframes, :iframe_sources]                                                   => :@iframes_parser
    delegate [:language, :title, :best_title, :author, :best_author, :description, :best_description,
              :h1, :h2, :h3, :h4, :h5, :h6]                                                => :@texts_parser

    # Deprecated compatibility shortcut; remove in 6.0.
    def favicon
      warn 'DEPRECATION WARNING: page.favicon is deprecated and will be removed in 6.0. ' \
           'Use page.images.favicon instead.'
      images.favicon
    end

    # Returns the whole parsed document
    def parsed
      @parsed ||= begin
        html = @document.to_s
        if @max_html_bytes && html.bytesize > @max_html_bytes
          raise MetaInspector::ParserError, "HTML is #{html.bytesize} bytes, exceeding the limit of #{@max_html_bytes} bytes"
        end
        html = HtmlEncoding.normalize(html).scrub
        # Keep libxml2's encoding detection and resource-limit validation. HTML5
        # has different limits and would otherwise accept oversized text nodes.
        document = Nokogiri::HTML(html)
        # For untagged bytes, let Nokogiri detect the declaration, then parse
        # again after the same conversion used for tagged strings. libxml2's
        # Windows-31J decoder still uses some strict Shift_JIS character mappings.
        if html.encoding == Encoding::BINARY && HtmlEncoding.superset(document.encoding)
          html = HtmlEncoding.normalize(html.dup.force_encoding(document.encoding))
          document = Nokogiri::HTML(html)
        end
        limit_error = document.errors.find do |error|
          error.message.match?(/Excessive depth in document|Resource limit exceeded|xmlSAX2Characters: huge text node/)
        end
        raise MetaInspector::ParserError, limit_error.message.strip if limit_error

        if (utf8 = html5_input(html, document))
          parsed = Nokogiri::HTML5(utf8, max_attributes: -1)
          parsed.errors.concat(document.errors)
          parsed
        else
          document
        end
      end
    rescue ArgumentError, EncodingError => error
      raise MetaInspector::ParserError.new(error)
    end

    private

    def html5_input(html, document)
      encoding = html.encoding == Encoding::BINARY ? document.encoding || 'UTF-8' : html.encoding.name
      encoding = encoding.sub(/\AISO_/i, 'ISO-').sub(/:\d+\z/, '')
      encoding = case encoding.downcase
                 when 'latin1', 'l1' then 'ISO-8859-1'
                 when 'gb_2312-80' then 'GB2312'
                 else encoding
                 end
      encoding = HtmlEncoding.superset(encoding) || encoding
      html.encode(Encoding::UTF_8, encoding, invalid: :replace, undef: :replace)
    rescue ArgumentError, Encoding::ConverterNotFoundError
      # libxml2 supports encodings (such as UTF-7) that Ruby cannot transcode.
      # Preserve the existing parser for those documents rather than rejecting them.
      nil
    end
  end
end
