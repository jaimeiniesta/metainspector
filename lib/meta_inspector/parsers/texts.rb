module MetaInspector
  module Parsers
    class TextsParser < Base
      delegate [:parsed, :meta] => :@main_parser

      sanitized_attributes :title, :best_title, :description

      # Returns the parsed document title, from the content of the <title> tag
      # within the <head> section.
      # Beware: Nokogiri's `inner_html` returns string in original encoding
      # http://www.nokogiri.org/tutorials/parsing_an_html_xml_document.html#encoding
      def title_node
        @title_node ||= begin
          title_tags = parsed.css('head title')
          title_tags.first if title_tags.any?
        end
      end

      def best_title_node
        @best_title_raw ||= if @main_parser.host =~ /\.youtube\.com$/
            meta['og:title']
          else
            find_best_title
          end
      end

      # A description getter that first checks for a meta description
      # and if not present will guess by looking at the first paragraph
      # with more than 120 characters
      def description_node
        @description_raw ||= begin
          return meta['description'] unless meta['description'].nil? || meta['description'].empty?
          secondary_description
        end
      end

      private

      # Look for candidates and pick the longest one
      def find_best_title
        candidates = [
            title_raw,
            parsed.css('body title'),
            meta['og:title'],
            parsed.css('h1').first
        ]
        candidates.flatten.compact.map do |candidate|
          #candidate = candidate.inner_html if candidate.respond_to? :inner_html
          candidate
        end.sort_by do |candidate|
          # We return raw html, but order should only depend on sanitized text length
          -sanitize(candidate).length
        end.first
      end

      # Look for the first <p> block with 120 characters or more
      def secondary_description
        first_long_paragraph = parsed.search('//p[string-length() >= 120]').first
        #first_long_paragraph ? first_long_paragraph.inner_html : ''
      end
    end
  end
end
