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
  end
end
