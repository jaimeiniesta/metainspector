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
          tag.attributes.to_h do |name, attribute|
            value = attribute.value
            value = URL.absolutify(value, base_url) if name == 'href'
            [name.to_sym, value]
          end
        end
      end

      def stylesheets
        @stylesheets ||= head_links.select { |hl| rel_includes?(hl[:rel], 'stylesheet') }
      end

      def canonicals
        @canonicals ||= head_links.select { |hl| rel_includes?(hl[:rel], 'canonical') }
      end

      def feeds
        @feeds ||= parsed.search('//link[@rel]').filter_map do |link|
          next unless rel_includes?(link['rel'], 'alternate')
          next unless KNOWN_FEED_TYPES.include?(media_type(link['type']))
          next if link['href'].to_s.strip.empty?

          { title: link['title'], href: URL.absolutify(link['href'], base_url), type: link['type'] }
        end
      end

      private

      # Media types are case-insensitive and may carry parameters
      # (https://mimesniff.spec.whatwg.org/#mime-type-essence).
      def media_type(type)
        type.to_s.split(';', 2).first.to_s.strip.downcase(:ascii)
      end

      def rel_includes?(rel, keyword)
        rel_tokens(rel).include?(keyword)
      end
    end
  end
end
