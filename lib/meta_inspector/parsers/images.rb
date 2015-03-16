require 'fastimage'

module MetaInspector
  module Parsers
    class ImagesParser < Base
      delegate [:parsed, :meta, :base_url]         => :@main_parser
      delegate [:each, :length, :size, :[], :last] => :images_collection

      include Enumerable

      def initialize(main_parser, options = {})
        @download_images = options[:download_images]
        super(main_parser)
      end

      def images
        self
      end

      # Returns either the Facebook Open Graph image, twitter suggested image or
      # the largest image in the image collection
      def best
        owner_suggested || largest
      end

      # Returns the parsed image from Facebook's open graph property tags
      # Most major websites now define this property and is usually relevant
      # See doc at http://developers.facebook.com/docs/opengraph/
      # If none found, tries with Twitter image
      def owner_suggested
        suggested_img = meta['og:image'] || meta['twitter:image']
        URL.absolutify(suggested_img, base_url) if suggested_img
      end

      # Returns the largest image from the image collection,
      # filtered for images that are more square than 10:1 or 1:10
      def largest()
        @larget_image ||= begin
          img_nodes = parsed.search('//img').select{ |img_node| img_node['src'] }
          sizes = img_nodes.map { |img_node| [URL.absolutify(img_node['src'], base_url), img_node['width'], img_node['height']] }
          sizes.uniq! { |url, width, height| url }
          if @download_images
            sizes.map! do |url, width, height|
              width, height = FastImage.size(url) if width.nil? || height.nil?
              [url, width, height]
            end
          else
            sizes.map! do |url, width, height|
              width, height = [0, 0] if width.nil? || height.nil?
              [url, width, height]
            end
          end
          sizes.map! { |url, width, height| [url, width.to_i * height.to_i, width.to_f / height.to_f] }
          sizes.keep_if { |url, area, ratio| ratio > 0.1 && ratio < 10 }
          sizes.sort_by! { |url, area, ratio| -area }
          url, area, ratio = sizes.first
          url
        end
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
        @images_collection ||= absolutified_images
      end

      def absolutified_images
        parsed_images.map { |i| URL.absolutify(i, base_url) }
      end

      def parsed_images
        cleanup(parsed.search('//img/@src'))
      end
    end
  end
end
