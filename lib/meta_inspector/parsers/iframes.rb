module MetaInspector
  module Parsers
    class IframesParser < Base
      delegate [:parsed, :base_url] => :@main_parser

      def iframes
        @iframes ||= parsed.search('//iframe').map do |iframe|
          iframe.attributes.to_h { |name, attribute| [name.to_sym, attribute.value] }
        end
      end

      def iframe_sources
        iframes.map do |attributes|
          src = attributes[:src].to_s.strip
          URL.absolutify(src, base_url, normalize: false) unless src.empty?
        end
      end
    end
  end
end
