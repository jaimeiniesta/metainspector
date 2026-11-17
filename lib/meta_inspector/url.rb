require 'addressable/uri'

module MetaInspector
  class URL
    attr_reader :url

    def initialize(initial_url, options = {})
      options        = self.class.defaults.merge(options)

      @normalize     = options[:normalize]

      self.url = initial_url
    end

    def scheme
      parsed(url) ? parsed(url).scheme : nil
    end

    def host
      parsed(url) ? parsed(url).host : nil
    end

    def root_url
      "#{scheme}://#{host}/"
    end

    WELL_KNOWN_TRACKING_PARAMS = %w( utm_source utm_medium utm_term utm_content utm_campaign )

    def tracked?
      u = parsed(url)
      return false unless u.query_values
      found_tracking_params = WELL_KNOWN_TRACKING_PARAMS & u.query_values.keys
      return found_tracking_params.any?
    end

    # Removes only the tracking key=value pairs, keeping the rest of the
    # query string as written: order, repeated keys and encoding.
    def untracked_url
      u = parsed(url)
      return url unless u.query
      params = u.query.split('&', -1)
      kept   = params.reject { |param| tracking_param?(param) }
      return url if kept.length == params.length
      u.query = kept.empty? ? nil : kept.join('&')
      u.to_s
    end

    def untrack!
      self.url = untracked_url if tracked?
    end

    def url=(new_url)
      url  = with_default_scheme(new_url)
      @url = @normalize ? normalized(url) : url
    end

    # Converts a relative URL to an absolute URL, like:
    #   "/faq" => "http://example.com/faq"
    # Respecting already absolute URLs like the ones starting with
    #   http:, ftp:, telnet:, mailto:, javascript: ...
    # Protocol-relative URLs are also resolved to use the same
    # schema as the base_url
    def self.absolutify(url, base_url, options = {})
      options = defaults.merge(options)
      if url =~ /^\w*\:/i
        MetaInspector::URL.new(url, options).url
      else
        uri = Addressable::URI.join(base_url, url)
        options[:normalize] ? normalize(uri) : uri.to_s
      end
    rescue MetaInspector::ParserError, Addressable::URI::InvalidURIError, ArgumentError
      nil
    end

    # Addressable's normalization, except for the query: reserved characters such
    # as ";" or "[]" and existing escapes are kept as written, since changing them
    # can change the resource (RFC 3986, 2.2). Only what can't be sent is escaped.
    def self.normalize(uri)
      normalized = uri.normalize
      normalized.query = escape_query(uri.query) if uri.query
      normalized.to_s
    end

    # Bytes allowed in a query by RFC 3986 (pchar, "/" and "?"), plus "[]" and
    # "%" when it starts an escape. Browsers send "[]" unescaped too.
    QUERY_UNSAFE = /%(?![0-9A-Fa-f]{2})|[^A-Za-z0-9\-._~!$&'()*+,;=:@\/?\[\]%]/n
    private_constant :QUERY_UNSAFE

    def self.escape_query(query)
      query.b.gsub(QUERY_UNSAFE) { |byte| format('%%%02X', byte.ord) }.force_encoding(Encoding::UTF_8)
    end

    private

    def self.defaults
      { :normalize => true }
    end

    def tracking_param?(param)
      key = Addressable::URI.unencode_component(param.split('=', 2).first)
      WELL_KNOWN_TRACKING_PARAMS.include?(key)
    end

    # Adds 'http' as default scheme, if there is none
    def with_default_scheme(url)
      parsed(url) && parsed(url).scheme.nil? ? 'http://' + url : url
    end

    # Normalize url to deal with characters that should be encoded,
    # add trailing slash, convert to downcase...
    def normalized(url)
      self.class.normalize(Addressable::URI.parse(url))
    rescue Addressable::URI::InvalidURIError => e
      raise MetaInspector::ParserError.new(e)
    end

    def parsed(url)
      Addressable::URI.parse(url)
    rescue Addressable::URI::InvalidURIError => e
      raise MetaInspector::ParserError.new(e)
    end
  end
end
