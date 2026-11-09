module MetaInspector
  module Parsers
    class IframesParser < Base
      delegate [:parsed, :base_url] => :@main_parser
      def iframes
        @iframes ||= parsed.search('//iframe').map do |iframe|
          iframe.attributes.each_with_object({}) do |(name, attribute), result|
            result[name.to_sym] = attribute.value
          end
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
