require 'nokogiri'

module MetaInspector
  # HTML uses browser-compatible supersets of several legacy encodings.
  # https://encoding.spec.whatwg.org/#names-and-labels
  module HtmlEncoding
    SUPERSETS = {
      Encoding.find('GB2312') => 'GBK',
      Encoding.find('Shift_JIS') => 'Windows-31J',
      Encoding.find('EUC-KR') => 'CP949',
      Encoding.find('Big5') => 'Big5-HKSCS',
      Encoding.find('ISO-8859-1') => 'Windows-1252'
    }.freeze

    def self.superset(label)
      SUPERSETS[Encoding.find(label)] if label
    rescue ArgumentError
      nil
    end

    def self.normalize(html)
      encoding = superset(html.encoding)
      return html unless encoding

      # Ruby's Big5-HKSCS byte validation rejects some sequences its transcoder
      # supports. Convert before scrub/tr can reject or replace those bytes.
      html.dup.force_encoding(encoding).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end

    # Resolve binary HTML before Nokogiri can choose a later meta tag.
    class Detector < Nokogiri::XML::SAX::Document
      BYTE_ORDER_MARKS = {
        "\x00\x00\xFE\xFF".b => 'UTF-32BE',
        "\xFF\xFE\x00\x00".b => 'UTF-32LE',
        "\xEF\xBB\xBF".b => 'UTF-8',
        "\xFE\xFF".b => 'UTF-16BE',
        "\xFF\xFE".b => 'UTF-16LE'
      }.freeze
      TEXT_ELEMENTS = %w[script style title textarea xmp iframe noembed noframes plaintext].freeze
      private_constant :BYTE_ORDER_MARKS, :TEXT_ELEMENTS

      def self.detect(html)
        # HTTP charsets and the encoding: option already tag the body string.
        return html.encoding.name unless html.encoding == Encoding::BINARY

        BYTE_ORDER_MARKS.each do |mark, encoding|
          return encoding if html.start_with?(mark)
        end

        catch(:metainspector_charset) do
          # Every byte is valid in Latin-1. Only markup matters during this scan;
          # using SAX avoids mistaking comments or script contents for meta tags.
          Nokogiri::HTML4::SAX::Parser.new(new, 'ISO-8859-1').parse(html) unless html.empty?
          nil
        end
      end

      def start_element(name, attributes = [])
        return if @text_element

        if TEXT_ELEMENTS.include?(name)
          @text_element = name
          return
        end
        return unless name == 'meta'

        attributes = attributes.to_h
        charset = attributes['charset']
        if !charset && attributes['http-equiv'].to_s.casecmp?('content-type')
          charset = attributes['content'].to_s[/(?:\A|;)\s*charset\s*=\s*["']?([^;\s"']+)/i, 1]
        end
        charset = charset.to_s.strip
        throw :metainspector_charset, charset unless charset.empty?
      end

      def end_element(name)
        @text_element = nil if name == @text_element
      end
    end
    private_constant :Detector

    def self.detect(html)
      Detector.detect(html)
    end
  end
end
