require 'addressable/uri'

module MetaInspector
  class URL
    attr_reader :url

    include MetaInspector::Exceptionable

    def initialize(initial_url, options = {})
      @exception_log = options[:exception_log]

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

    def url=(new_url)
      @url = normalized(with_default_scheme(new_url))
    end

    # Converts a protocol-relative url to its full form,
    # depending on the scheme of the page that contains it
    def self.unrelativize(url, scheme)
      url =~ /^\/\// ? "#{scheme}://#{url[2..-1]}" : url
    end

    # Converts a relative URL to an absolute URL, like:
    #   "/faq" => "http://example.com/faq"
    # Respecting already absolute URLs like the ones starting with
    #   http:, ftp:, telnet:, mailto:, javascript: ...
    def self.absolutify(url, base_url)
      if url =~ /^\w*\:/i
        MetaInspector::URL.new(url).url
      else
        Addressable::URI.join(base_url, url).normalize.to_s
      end
    rescue Addressable::URI::InvalidURIError
      nil
    end

    private

    # Adds 'http' as default scheme, if there is none
    def with_default_scheme(url)
      parsed(url) && parsed(url).scheme.nil? ? 'http://' + url : url
    end

    # Normalize url to deal with characters that should be encoded,
    # add trailing slash, convert to downcase...
    def normalized(url)
      Addressable::URI.parse(url).normalize.to_s
    end

    def parsed(url)
      Addressable::URI.parse(url)
    rescue Addressable::URI::InvalidURIError => e
      @exception_log << e
      nil
    end
  end
end
