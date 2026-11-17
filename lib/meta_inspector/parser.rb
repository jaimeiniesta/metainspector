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
    # libxml2's limit for a single text node, attribute value or comment
    # (XML_MAX_TEXT_LENGTH).
    MAX_NODE_BYTES = 10_000_000

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
    delegate [:head_links, :stylesheets, :canonicals, :feeds]                              => :@head_links_parser
    delegate [:links, :base_url]                                                           => :@links_parser
    delegate :images                                                                       => :@images_parser
    delegate [:iframes, :iframe_sources]                                                   => :@iframes_parser
    delegate [:language, :title, :best_title, :author, :best_author, :description, :best_description,
              :h1, :h2, :h3, :h4, :h5, :h6]                                                => :@texts_parser

    # Returns the whole parsed document
    def parsed
      @parsed ||= begin
        html = @document.to_s
        if @max_html_bytes && html.bytesize > @max_html_bytes
          raise MetaInspector::ParserError, "HTML is #{html.bytesize} bytes, exceeding the limit of #{@max_html_bytes} bytes"
        end
        html = HtmlEncoding.normalize(html).scrub
        # Keep libxml2's resource-limit validation. HTML5 has different limits
        # and would otherwise accept oversized text nodes.
        document = Nokogiri::HTML(html, nil, HtmlEncoding.detect(html))
        # For untagged bytes, use the selected declaration, then parse
        # again after the same conversion used for tagged strings. libxml2's
        # Windows-31J decoder still uses some strict Shift_JIS character mappings.
        if html.encoding == Encoding::BINARY && HtmlEncoding.superset(document.encoding)
          html = HtmlEncoding.normalize(html.dup.force_encoding(document.encoding))
          document = Nokogiri::HTML(html)
        end
        raise_limit_error(document, /Resource limit exceeded|xmlSAX2Characters: huge text node/)

        if (utf8 = html5_input(html, document))
          # The HTML5 tree is the DOM and enforces its own depth limit, so
          # libxml2's depth error doesn't apply: its HTML4 tree can be much
          # deeper, as it leaves elements open that HTML5 closes (#612).
          parsed = html5_document(utf8, document)
          enforce_node_size_limit(parsed, utf8, document)
          parsed
        else
          # libxml2's tree is the DOM, and past its depth limit it's truncated.
          raise_limit_error(document, /Excessive depth in document/)
          document
        end
      end
    rescue ArgumentError, EncodingError => error
      raise MetaInspector::ParserError.new(error)
    end

    private

    def raise_limit_error(document, pattern)
      return if non_html_content?

      limit_error = document.errors.find { |error| error.message.match?(pattern) }
      raise MetaInspector::ParserError, limit_error.message.strip if limit_error
    end

    # libxml2 may stop reading at a fatal error, such as its depth limit, so it
    # may not have checked the size of everything after that point. Then apply
    # its limit to the HTML5 tree, which has none of its own. Skip inputs too
    # small to hold an oversized node: HTML5 parsing turns a byte into at most
    # 3 (NUL to U+FFFD).
    def enforce_node_size_limit(parsed, html, document)
      return if non_html_content? || html.bytesize * 3 <= MAX_NODE_BYTES
      return unless document.errors.any?(&:fatal?)

      kind = catch(:oversized) do
        parsed.traverse do |node|
          if node.element?
            throw :oversized, 'attribute value' if node.attribute_nodes.any? { |a| a.value.bytesize > MAX_NODE_BYTES }
          elsif node.comment?
            throw :oversized, 'comment' if node.content.bytesize > MAX_NODE_BYTES
          elsif node.text? || node.cdata?
            throw :oversized, 'text node' if node.content.bytesize > MAX_NODE_BYTES
          end
        end
        nil
      end
      raise MetaInspector::ParserError, "Resource limit exceeded: #{kind} longer than #{MAX_NODE_BYTES} bytes" if kind
    end

    def html5_document(html, fallback)
      parsed = Nokogiri::HTML5(html, max_attributes: -1, parse_noscript_content_as_text: true)
      restore_noscript_content(parsed)
      parsed.errors.concat(fallback.errors)
      parsed
    rescue ArgumentError
      raise unless non_html_content?

      # Binary files and XML feeds can nest past the HTML5 tree depth limit.
      # The caller accepted non-HTML content, so keep libxml2's tree, whose
      # depth is already capped, as 5.21.0 did.
      fallback
    end

    # The caller opted in with allow_non_html_content and the response is not
    # HTML, so resource limits that guard against truncated HTML do not apply.
    def non_html_content?
      return false unless @document.allow_non_html_content

      content_type = @document.content_type
      !content_type.nil? && content_type != 'text/html'
    end

    def restore_noscript_content(document)
      document.css('noscript').each do |node|
        # Isolate fallback markup so it cannot close the head or consume the
        # rest of the page, while keeping it available to all extractors.
        node.children = Nokogiri::HTML5.fragment(node.text, max_attributes: -1)
      end
    end

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
