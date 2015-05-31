require 'fastimage'

module MetaInspector
  module Parsers
    class ImagesParser < Base
      delegate [:parsed, :meta, :base_url]         => :@main_parser
      delegate [:each, :length, :size, :[], :last] => :images_collection

      include Enumerable

      def initialize(main_parser, options = {})
        @download_images = options.fetch(:download_images, true)
        super(main_parser)
      end

      def images
        self
      end

      # Returns either the Facebook Open Graph image, twitter suggested image or
      # the largest image in the image collection
      def best
        owner_suggested || detect_best_image
      end

      def detect_best_image
        meaningful_images.first
      end

      # Returns the parsed image from Facebook's open graph property tags
      # Most major websites now define this property and is usually relevant
      # See doc at http://developers.facebook.com/docs/opengraph/
      # If none found, tries with Twitter image
      def owner_suggested
        suggested_img = (microdata_image || meta['og:image'] || meta['twitter:image'])
        URL.absolutify(suggested_img, base_url) if suggested_img
      end

      # Returns an array of [img_url, width, height] sorted by image area (width * height)
      def with_size
        @with_size ||= begin
          img_nodes = parsed.search('//img').select{ |img_node| img_node['src'] }
          imgs_with_size = img_nodes.map { |img_node| [URL.absolutify(img_node['src'], base_url), img_node['width'], img_node['height']] }
          imgs_with_size.uniq! { |url, width, height| url }
          if @download_images
            imgs_with_size.map! do |url, width, height|
              width, height = FastImage.size(url) if width.nil? || height.nil?
              [url, width.to_i, height.to_i]
            end
          else
            imgs_with_size.map! do |url, width, height|
              width, height = [0, 0] if width.nil? || height.nil?
              [url, width.to_i, height.to_i]
            end
          end
          imgs_with_size.sort_by { |url, width, height| -(width.to_i * height.to_i) }
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

      def microdata_image
        query = '//*[@itemscope]/*[@itemprop="image"]'
        query = parsed.xpath(query)[0]
        query && query.inner_text
      end

      def meaningful_images
        @meaningful_images ||= with_size.reject { |url, w, h|
          url =~ blacklist
        }.reject { |url, w, h|
           !h || !w
        }.reject { |url, w, h|
          (w != 0 && h != 0) ? (h / w > 3 || w / h > 3 || h * w < 5000) : false
        }.sort_by { |url, w, h|
          -h * w
        }.map(&:first)
      end

      def images_collection
        @images_collection ||= absolutified_images
      end

      def absolutified_images
        parsed_images.map { |i| URL.absolutify(i, base_url) }
      end

      def parsed_images
        cleanup(parsed.search('//img/@src'))
      end

      def blacklist
        Regexp.union 'banner', 'background', 'empty', 'sprite', 'base64', '.gif', '.tiff'
      end

    end
  end
end
