module MetaInspector
  module Parsers
    class HeadLinksParser < Base
      delegate [:parsed, :base_url] => :@main_parser

      # application/json is JSON Feed 1.0; application/feed+json is 1.1.
      KNOWN_FEED_TYPES = %w[
        application/rss+xml application/atom+xml application/json application/feed+json
      ].freeze

      def head_links
        @head_links ||= parsed.css('head link').map do |tag|
          Hash[
            tag.attributes.keys.map do |key|
              keysym = key.to_sym
              val = tag.attributes[key].value
              val = URL.absolutify(val, base_url) if keysym == :href
              [keysym, val]
            end
          ]
        end
      end

      def stylesheets
        @stylesheets ||= head_links.select { |hl| rel_includes?(hl[:rel], 'stylesheet') }
      end

      def canonicals
        @canonicals ||= head_links.select { |hl| rel_includes?(hl[:rel], 'canonical') }
      end

      def feeds
        @feeds ||=
          parsed.search('//link[@rel]').map do |link|
            next unless rel_includes?(link['rel'], 'alternate')
            next if !KNOWN_FEED_TYPES.include?(media_type(link["type"])) || link["href"].to_s.strip == ''

            {
              title: link["title"],
              href: URL.absolutify(link["href"], base_url),
              type: link["type"]
            }
          end.compact
      end

      # Deprecated compatibility method; remove in 6.0.
      def feed
        warn 'DEPRECATION WARNING: page.feed is deprecated and will be removed in 6.0. ' \
             'Use page.feeds instead.'
        first_feed = feeds.find { |link| %w[application/rss+xml application/atom+xml].include?(media_type(link[:type])) }
        first_feed && first_feed[:href]
      end

      private

      # Media types are case-insensitive and may carry parameters
      # (https://mimesniff.spec.whatwg.org/#mime-type-essence).
      def media_type(type)
        type.to_s.split(';', 2).first.to_s.strip.downcase(:ascii)
      end

      def rel_includes?(rel, keyword)
        rel.to_s.downcase(:ascii).split(/[ \t\n\f\r]+/).include?(keyword)
      end
    end
  end
end
