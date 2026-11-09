module MetaInspector
  module Parsers
    class IframesParser < Base
      delegate [:parsed, :base_url] => :@main_parser
      delegate [:each, :length, :size, :[], :last] => :src

      include Enumerable

      def iframes
        self
      end

      # Returns the source of every iframe on the page as an absolute URL
      def src
        @src ||= cleanup(parsed.search('//iframe/@src'))
                   .map { |url| URL.absolutify(url, base_url, normalize: false) }
                   .compact
      end
    end
  end
end
