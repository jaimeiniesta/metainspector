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
        @best_title = meta['og:title'] if @main_parser.host =~ /\.youtube\.com$/
        @best_title ||= find_best_title
      end

      # Returns the meta description, if present
      def description
        @description ||= meta['description']
      end

      # A description getter that returns the first non-nill description
      # from the following candidates:
      # - the standard meta description
      # - the og:description meta tag
      # - the twitter:description meta tag
      # - the first paragraph with more than 120 characters
      def best_description
        @best_description ||= find_best_description
      end

      private

      # Look for candidates and pick the longest one
      def find_best_title
        candidates = [
            parsed.css('head title'),
            parsed.css('body title'),
            meta['og:title'],
            parsed.css('h1').first
        ]
        candidates.flatten!
        candidates.compact!
        candidates.map! { |c| (c.respond_to? :inner_text) ? c.inner_text : c }
        candidates.map! { |c| c.strip }
        return nil if candidates.empty?
        candidates.map! { |c| c.gsub(/\s+/, ' ') }
        candidates.uniq!
        candidates.sort_by! { |t| -t.length }
        candidates.first
      end

      def find_best_description
        candidates = [
          meta['description'],
          meta['og:description'],
          meta['twitter:description'],
          secondary_description
        ]
        candidates.find { |x| !x.to_s.empty? }
      end

      # Look for the first <p> block with 120 characters or more
      def secondary_description
        first_long_paragraph = parsed.search('//p[string-length() >= 120]').first
        first_long_paragraph ? first_long_paragraph.text : ''
      end
    end
  end
end
