module MetaInspector
  module Parsers
    class IframesParser < Base
      delegate [:parsed, :base_url] => :@main_parser
      delegate [:each, :length, :size, :[], :last] => :attributes

      include Enumerable

      def iframes
        self
      end

      # Returns a hash of all attributes for every iframe on the page.
      # The src attribute is resolved to an absolute URL; the rest are kept as-is.
      def attributes
        @attributes ||= parsed.search('//iframe').map do |iframe|
          attrs = iframe.attributes.each_with_object({}) do |(name, attribute), result|
            result[name.to_sym] = attribute.value
          end
          attrs[:src] = URL.absolutify(attrs[:src], base_url, normalize: false) unless attrs[:src].to_s.strip.empty?
          attrs
        end
      end

      # Returns the source of every iframe on the page as an absolute URL
      def src
        @src ||= attributes.map { |attrs| attrs[:src] }
                           .reject { |url| url.to_s.strip.empty? }
                           .uniq
      end
    end
  end
end
