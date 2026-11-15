module MetaInspector
  module Parsers
    class HeadLinksParser < Base
      delegate [:parsed, :base_url] => :@main_parser

      KNOWN_FEED_TYPES = %w[
        application/rss+xml application/atom+xml application/json
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
            next if !KNOWN_FEED_TYPES.include?(link["type"]) || link["href"].to_s.strip == ''

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
        first_feed = feeds.find { |link| %r{/(rss|atom)\+xml$}i.match?(link[:type]) }
        first_feed && first_feed[:href]
      end

      private

      def rel_includes?(rel, keyword)
        rel.to_s.downcase(:ascii).split(/[ \t\n\f\r]+/).include?(keyword)
      end
    end
  end
end
