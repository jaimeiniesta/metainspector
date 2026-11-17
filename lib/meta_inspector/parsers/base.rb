module MetaInspector
  module Parsers
    ##
    # Base class from where the specialized parsers inherit from.
    #
    # On initialization a main parser is expected, so the specialized
    # parsers can request the parsed document to the main parser, and
    # then perform the searches on it.
    #
    # The main parser also serves as a message hub between the specialized
    # parsers. For example, the ImagesParser needs to know the base_url
    # in order to absolutify image URLs, so it delegates it to the main parser
    # which, in turn, delegates it to the LinksParser.
    #
    class Base
      extend Forwardable

      def initialize(main_parser)
        @main_parser = main_parser
      end

      private

      # Cleans up nokogiri search results
      def cleanup(results)
        results.map { |r| r.value.strip }.reject(&:empty?).uniq
      end

      # Splits a rel attribute into its tokens, lowercased as HTML does: ASCII only.
      def rel_tokens(rel)
        rel.to_s.downcase(:ascii).split(/[ \t\n\f\r]+/)
      end
    end
  end
end
