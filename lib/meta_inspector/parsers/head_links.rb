module MetaInspector
  module Parsers
    class HeadLinksParser < Base
      delegate [:parsed, :base_url] => :@main_parser

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
        feed = parsed.search("//link[@type='application/#{format}+xml']").find{|link| link.attributes["href"] }
        feed ? URL.absolutify(feed['href'], base_url) : nil
      end
    end
  end
end
