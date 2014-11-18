module MetaInspector
  module Parsers
    class ImagesParser < Base
      def_delegators :@main_parser, :parsed, :meta, :base_url
      def_delegators :images_collection, :each, :length, :size, :last, :[]

      include Enumerable

      def images
        self
      end

      # Returns the parsed image from Facebook's open graph property tags
      # Most all major websites now define this property and is usually very relevant
      # See doc at http://developers.facebook.com/docs/opengraph/
      # If none found, tries with Twitter image
      def best
        meta['og:image'] || meta['twitter:image'] || images_collection.first
      end

      # Return favicon url if exist
      def favicon
        query = '//link[@rel="icon" or contains(@rel, "shortcut")]'
        value = parsed.xpath(query)[0].attributes['href'].value
        @favicon ||= URL.absolutify(value, base_url)
      rescue
        nil
      end

      private

      def images_collection
        @images_collection ||= parsed_images.map{ |i| URL.absolutify(i, base_url) }
      end

      def parsed_images
        @parsed_images ||= cleanup(parsed.search('//img/@src'))
      end
    end
  end
end
