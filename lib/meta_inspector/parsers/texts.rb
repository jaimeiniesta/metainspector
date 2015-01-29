module MetaInspector
  module Parsers
    class TextsParser < Base
      delegate [:parsed, :meta] => :@main_parser

      # Returns the parsed document title, from the content of the <title> tag
      # within the <head> section.
      def title
        @title ||= parsed.css('head title').inner_text rescue nil
      end

      def best_title
        @best_title ||= begin
          candidates = [
              parsed.css('head title'),
              parsed.css('body title'),
              meta['og:title'],
              parsed.css('h1').first
          ]
          candidates.flatten!
          candidates.map! { |c| (c.respond_to? :inner_text) ? c.inner_text : c }
          candidates.compact!
          candidates.map! { |c| c.gsub(/\s+/, ' ') }
          candidates.uniq!
          candidates.sort_by! { |t| -t.length }
          candidates.first.strip
        end
      end

      # A description getter that first checks for a meta description
      # and if not present will guess by looking at the first paragraph
      # with more than 120 characters
      def description
        meta['description'] || secondary_description
      end

      private

      # Look for the first <p> block with 120 characters or more
      def secondary_description
        first_long_paragraph = parsed.search('//p[string-length() >= 120]').first
        first_long_paragraph ? first_long_paragraph.text : ''
      end
    end
  end
end
