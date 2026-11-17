module MetaInspector
  module Parsers
    class LinksParser < Base
      delegate [:parsed, :url, :scheme, :host] => :@main_parser

      def links
        self
      end

      # Returns all links found, unprocessed.
      # Matches <a> by local name: in the HTML5 tree, links inside inline
      # <svg> or <math> are in another namespace, and '//a' would miss them.
      def raw
        @raw ||= cleanup(parsed.xpath('//*[local-name()="a"]/@href')).compact.uniq
      end

      # Returns all links found, unrelavitized and absolutified
      def all
        @all ||= raw.map { |link| URL.absolutify(link, base_url) }.compact.uniq
      end

      # Returns all HTTP links found
      def http
        @http ||= all.select { |link| link =~ /^http(s)?:\/\//i}
      end

      # Returns all non-HTTP links found
      def non_http
        @non_http ||= all.select { |link| link !~ /^http(s)?:\/\//i}
      end

      # Returns all internal HTTP links found
      def internal
        @internal ||= http.select { |link| URL.new(link).host == host }
      end

      # Returns all external HTTP links found
      def external
        @external ||= http.select { |link| URL.new(link).host != host }
      end

      def to_hash
        { 'internal' => internal,
          'external' => external,
          'non_http' => non_http }
      end

      # Returns the base url to absolutify relative links.
      # This can be the one set on a <base> tag,
      # or the url of the document if no <base> tag was found.
      # Relative base hrefs are resolved against the document URL.
      def base_url
        current_base_href = base_href.to_s.strip.empty? ? nil : URL.absolutify(base_href, url)
        current_base_href || url
      end

      # Returns the value of the href attribute on the <base /> tag, if exists.
      # Memoized, nil included, as it's needed once per link, image, iframe
      # and head link, and searching the whole document every time is slow.
      def base_href
        return @base_href if defined?(@base_href)

        @base_href = parsed.search('base').first.attributes['href'].value rescue nil
      end
    end
  end
end
