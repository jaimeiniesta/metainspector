# -*- encoding: utf-8 -*-

module MetaInspector
  class URL
    attr_reader :url
    
    include MetaInspector::Exceptionable

    def initialize(url, options = {})
      options         = defaults.merge(options)
      @exception_log  = options[:exception_log]

      @url            = with_default_scheme(normalized(url))
    end

    def scheme
      URI.parse(url).scheme
    end

    def host
      URI.parse(url).host
    end

    def root_url
      "#{scheme}://#{host}/"
    end

    private

    def defaults
      { exception_log: MetaInspector::ExceptionLog.new }
    end

    # Adds 'http' as default scheme, if there is none
    def with_default_scheme(url)
      URI.parse(url).scheme.nil? ? 'http://' + url : url

      rescue URI::InvalidURIError, URI::InvalidComponentError => e
        @exception_log << e
        url
    end

    # Normalize url to deal with characters that should be encodes, add trailing slash, convert to downcase...
    def normalized(url)
      Addressable::URI.parse(url).normalize.to_s
    end
  end
end
