module MetaInspector
  module Parsers
    class LinksParser < Base
      def_delegators :@main_parser, :parsed, :url, :scheme, :host

      def links
        self
      end

      # Returns all links found, unprocessed
      def raw
        @raw ||= cleanup(parsed.search("//a/@href")).compact.uniq
      end

      # Returns all links found, unrelavitized and absolutified
      def all
        @all ||= raw.map { |l| URL.absolutify(URL.unrelativize(l, scheme), base_url) }
                    .compact.uniq
      end

      # Returns all HTTP links found
      def http
        @http ||= all.select {|l| l =~ /^http(s)?:\/\//i}
      end

      # Returns all non-HTTP links found
      def non_http
        @non_http ||= all.select {|l| l !~ /^http(s)?:\/\//i}
      end

      # Returns all internal HTTP links found
      def internal
        @internal ||= http.select {|link| URL.new(link).host == host }
      end

      # Returns all external HTTP links found
      def external
        @external ||= http.select {|link| URL.new(link).host != host }
      end

      def to_hash
        { 'internal' => internal, 'external' => external, 'non_http' => non_http }
      end

      # Returns the parsed document meta rss link
      def feed
        @feed ||= (parsed_feed('rss') || parsed_feed('atom'))
      end

      # Returns the base url to absolutify relative links. This can be the one set on a <base> tag,
      # or the url of the document if no <base> tag was found.
      def base_url
        base_href || url
      end

      private

      def parsed_feed(format)
        feed = parsed.search("//link[@type='application/#{format}+xml']").first
        feed ? URL.absolutify(feed.attributes['href'].value, base_url) : nil
      end

      # Returns the value of the href attribute on the <base /> tag, if it exists
      def base_href
        parsed.search('base').first.attributes['href'].value rescue nil
      end
    end
  end
end
