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
      Encoding.find('ISO-8859-1') => 'Windows-1252',
      Encoding.find('US-ASCII') => 'Windows-1252',
      Encoding.find('ISO-8859-9') => 'Windows-1254',
      Encoding.find('ISO-8859-11') => 'Windows-874',
      Encoding.find('TIS-620') => 'Windows-874'
    }.freeze

    # Labels browsers accept, keyed by the Ruby name of their encoding.
    # The replacement and x-user-defined encodings are left out: their labels
    # are ignored like unknown ones.
    LABELS = {
      'UTF-8' => %w[unicode-1-1-utf-8 unicode11utf8 unicode20utf8 utf-8 utf8 x-unicode20utf8],
      'IBM866' => %w[866 cp866 csibm866 ibm866],
      'ISO-8859-2' => %w[csisolatin2 iso-8859-2 iso-ir-101 iso8859-2 iso88592 iso_8859-2 iso_8859-2:1987 l2 latin2],
      'ISO-8859-3' => %w[csisolatin3 iso-8859-3 iso-ir-109 iso8859-3 iso88593 iso_8859-3 iso_8859-3:1988 l3 latin3],
      'ISO-8859-4' => %w[csisolatin4 iso-8859-4 iso-ir-110 iso8859-4 iso88594 iso_8859-4 iso_8859-4:1988 l4 latin4],
      'ISO-8859-5' => %w[csisolatincyrillic cyrillic iso-8859-5 iso-ir-144 iso8859-5 iso88595 iso_8859-5
                         iso_8859-5:1988],
      'ISO-8859-6' => %w[arabic asmo-708 csiso88596e csiso88596i csisolatinarabic ecma-114 iso-8859-6 iso-8859-6-e
                         iso-8859-6-i iso-ir-127 iso8859-6 iso88596 iso_8859-6 iso_8859-6:1987],
      'ISO-8859-7' => %w[csisolatingreek ecma-118 elot_928 greek greek8 iso-8859-7 iso-ir-126 iso8859-7 iso88597
                         iso_8859-7 iso_8859-7:1987 sun_eu_greek],
      # Includes the ISO-8859-8-I labels, which only differ in text direction.
      'ISO-8859-8' => %w[csiso88598e csisolatinhebrew hebrew iso-8859-8 iso-8859-8-e iso-ir-138 iso8859-8 iso88598
                         iso_8859-8 iso_8859-8:1988 visual csiso88598i iso-8859-8-i logical],
      'ISO-8859-10' => %w[csisolatin6 iso-8859-10 iso-ir-157 iso8859-10 iso885910 l6 latin6],
      'ISO-8859-13' => %w[iso-8859-13 iso8859-13 iso885913],
      'ISO-8859-14' => %w[iso-8859-14 iso8859-14 iso885914],
      'ISO-8859-15' => %w[csisolatin9 iso-8859-15 iso8859-15 iso885915 iso_8859-15 l9],
      'ISO-8859-16' => %w[iso-8859-16],
      'KOI8-R' => %w[cskoi8r koi koi8 koi8-r koi8_r],
      'KOI8-U' => %w[koi8-ru koi8-u],
      'macRoman' => %w[csmacintosh mac macintosh x-mac-roman],
      'Windows-874' => %w[dos-874 iso-8859-11 iso8859-11 iso885911 tis-620 windows-874],
      'Windows-1250' => %w[cp1250 windows-1250 x-cp1250],
      'Windows-1251' => %w[cp1251 windows-1251 x-cp1251],
      'Windows-1252' => %w[ansi_x3.4-1968 ascii cp1252 cp819 csisolatin1 ibm819 iso-8859-1 iso-ir-100 iso8859-1
                           iso88591 iso_8859-1 iso_8859-1:1987 l1 latin1 us-ascii windows-1252 x-cp1252],
      'Windows-1253' => %w[cp1253 windows-1253 x-cp1253],
      'Windows-1254' => %w[cp1254 csisolatin5 iso-8859-9 iso-ir-148 iso8859-9 iso88599 iso_8859-9 iso_8859-9:1989
                           l5 latin5 windows-1254 x-cp1254],
      'Windows-1255' => %w[cp1255 windows-1255 x-cp1255],
      'Windows-1256' => %w[cp1256 windows-1256 x-cp1256],
      'Windows-1257' => %w[cp1257 windows-1257 x-cp1257],
      'Windows-1258' => %w[cp1258 windows-1258 x-cp1258],
      'macCyrillic' => %w[x-mac-cyrillic x-mac-ukrainian],
      'GBK' => %w[chinese csgb2312 csiso58gb231280 gb2312 gb_2312 gb_2312-80 gbk iso-ir-58 x-gbk],
      'GB18030' => %w[gb18030],
      'Big5' => %w[big5 big5-hkscs cn-big5 csbig5 x-x-big5],
      'EUC-JP' => %w[cseucpkdfmtjapanese euc-jp x-euc-jp],
      'ISO-2022-JP' => %w[csiso2022jp iso-2022-jp],
      'Shift_JIS' => %w[csshiftjis ms932 ms_kanji shift-jis shift_jis sjis windows-31j x-sjis],
      'EUC-KR' => %w[cseuckr csksc56011987 euc-kr iso-ir-149 korean ks_c_5601-1987 ks_c_5601-1989 ksc5601
                     ksc_5601 windows-949],
      'UTF-16BE' => %w[unicodefffe utf-16be],
      'UTF-16LE' => %w[csunicode iso-10646-ucs-2 ucs-2 unicode unicodefeff utf-16 utf-16le]
    }.flat_map { |encoding, labels| labels.map { |label| [label, encoding] } }.to_h.freeze

    # Returns the encoding for a charset label, or nil if browsers don't know it.
    def self.resolve(label)
      LABELS[label.to_s.strip.downcase]
    end

    def self.ruby_encoding?(label)
      Encoding.find(label)
      true
    rescue ArgumentError
      false
    end

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

        encoding = byte_order_mark_encoding(html)
        return encoding if encoding

        detector = new
        catch(:metainspector_charset) do
          # Every byte is valid in Latin-1. Only markup matters during this scan;
          # using SAX avoids mistaking comments or script contents for meta tags.
          Nokogiri::HTML4::SAX::Parser.new(detector, 'ISO-8859-1').parse(html) unless html.empty?
          # Name the default rather than return nil, or libxml2 would read the
          # unknown label from the meta tag and stop parsing there.
          'Windows-1252' if detector.unknown_label
        end
      end

      attr_reader :unknown_label

      def self.byte_order_mark_encoding(html)
        BYTE_ORDER_MARKS.each do |mark, encoding|
          return encoding if html.start_with?(mark)
        end
        nil
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
        return if charset.to_s.strip.empty?

        encoding = HtmlEncoding.resolve(charset)
        # A page whose meta tag can be read as ASCII isn't UTF-16.
        # https://html.spec.whatwg.org/multipage/parsing.html#prescan-a-byte-stream-to-determine-its-encoding
        encoding = 'UTF-8' if encoding&.start_with?('UTF-16')
        # Keep labels that only Ruby and libxml2 know, such as UTF-7.
        encoding ||= charset.strip if HtmlEncoding.ruby_encoding?(charset.strip)
        throw :metainspector_charset, encoding if encoding

        @unknown_label = true
      end

      def end_element(name)
        @text_element = nil if name == @text_element
      end
    end
    private_constant :Detector

    def self.detect(html)
      Detector.detect(html)
    end

    def self.byte_order_mark_encoding(html)
      Detector.byte_order_mark_encoding(html) if html.encoding == Encoding::BINARY
    end
  end
end
