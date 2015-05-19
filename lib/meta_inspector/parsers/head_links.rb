module MetaInspector
  module Parsers
    class HeadLinksParser < Base
      delegate [:parsed, :base_url] => :@main_parser

      def head_links
        @head_links ||= parsed.css('head link').map do |tag|
          Hash[tag.attributes.keys.map { |key| [key.to_sym, tag.attributes[key].value] }]
        end
      end

      def stylesheets
        @stylesheets ||= head_links.select { |hl| hl[:rel] == 'stylesheet' }
      end

      def canonicals
        @canonicals ||= head_links.select { |hl| hl[:rel] == 'canonical' }
      end

      # Returns the parsed document meta rss link
      def feed
        @feed ||= (parsed_feed('rss') || parsed_feed('atom'))
      end

      private

      def parsed_feed(format)
        feed = parsed.search("//link[@type='application/#{format}+xml']").first
        feed ? URL.absolutify(feed.attributes['href'].value, base_url) : nil
      end
    end
  end
end
