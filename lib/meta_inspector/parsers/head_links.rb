module MetaInspector
  module Parsers
    class HeadLinksParser < Base
      delegate :parsed => :@main_parser

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

    end
  end
end
