require 'fastimage'

module MetaInspector
  module Parsers
    class ImagesParser < Base
      DEFAULT_IMG_BLACKLIST =  ['.woff', '.font', '.tiff', '.tif', 'data:'].freeze

      delegate [:parsed, :meta, :base_url]         => :@main_parser
      delegate [:each, :length, :size, :[], :last] => :images_collection

      include Enumerable

      def initialize(main_parser, options = {})
        @download_images = options[:download_images]
        @fetch_all_image_meta = options[:fetch_all_image_meta]
        @image_blacklist_words =  options[:image_blacklist_words] || DEFAULT_IMG_BLACKLIST
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
        suggested_img = content_of(meta['og:image']) || content_of(meta['twitter:image'])
        URL.absolutify(suggested_img, base_url, normalize: false) if suggested_img
      end

      # Returns an array of [img_url, width, height] sorted by image area (width * height)
      def with_size
        @with_size ||= begin
           img_nodes = parsed.search('//img') #.select{ |img_node| img_node['src'] }

           imgs_with_size = img_nodes.map do |img_node|
             if img_node['srcset']
               img_with_size_from_srcset(img_node)
             else
               src_value = img_node.attr('data-src') || img_node.attr('data-image') || img_node.attr('data-img') || img_node.attr('src')
               if src_value.present?
                 [URL.absolutify(src_value, base_url, normalize: false), img_node['width'], img_node['height']]
               end
             end
           end

           imgs_with_size += bg_and_other_imgs(parsed)

           imgs_with_size.compact!
           imgs_with_size.uniq! { |url, width, height| url }

           # Remove any urls that have been blacklisted
           imgs_with_size.reject! { |url| @image_blacklist_words.any? { |blacklist_word| url.first.include?(blacklist_word) } }

           if @download_images
             imgs_with_size.map! do |img_with_size|
               image_with_meta(img_with_size)
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

      # Returns the largest image from the image collection,
      # filtered for images that are more square than 10:1 or 1:10
      def largest
        @largest_image ||= begin
          imgs_with_size = with_size.dup
          imgs_with_size.keep_if do |url, width, height|
            ratio = width.to_f / height.to_f
            ratio > 0.1 && ratio < 10
          end
          url, width, height = imgs_with_size.first
          url
        end
      end

      # Return favicon url if exist
      def favicon
        query = '//link[@rel="icon" or contains(@rel, "shortcut")]'
        value = parsed.xpath(query)[0].attributes['href'].value
        @favicon ||= URL.absolutify(value, base_url, normalize: false)
      rescue
        nil
      end

      private

      def image_with_meta(img_with_size)
        url, width, height  = img_with_size
        file_type = nil
        file_size = nil

        if @fetch_all_image_meta
          # Fetch everything, dimensions, size, type
          fast_img = FastImage.new(url)
          width, height = fast_img.size
          file_type = fast_img.type
          file_size = fast_img.content_length
        else
          # Only fetch size if you haven't detected it yet
          width, height = FastImage.size(url) if width.nil? || height.nil?
        end
        [url, width.to_i, height.to_i, file_type, file_size]
      end

      # Analyze the srcset and attempt to choose the largest image from it.
      def img_with_size_from_srcset(srcset_img)
        srcset_values = srcset_img['srcset']&.split(',')
        largest_src = Array.wrap(srcset_values).map do |srcset_value|
          srcset_value_img_props = srcset_value.split
          { url: srcset_value_img_props.first, size: srcset_value_img_props.last.to_i }
        end.sort_by { |v| -v[:size] }.first.dig(:url)
        return unless largest_src.present?
        [URL.absolutify(largest_src.strip, base_url, normalize: false), 0, 0]
      end

      def bg_and_other_imgs(parsed_document)
        imgs = []
        # Find any css bg images
        imgs += parsed_document.to_html.scan(/\burl\s*\(\s*["']?([^"'\r\n\)\(]+)["']?\s*\)/).map do |background_image_url|
          [URL.absolutify(background_image_url.first&.strip, base_url, normalize: false), 0, 0]
        end

        # Find any elements that have bg or background data attributes
        imgs += parsed_document.xpath("//@data-bg|//@data-background").map do |data_bg|
          [URL.absolutify(data_bg.value&.strip, base_url, normalize: false), 0, 0] if data_bg.try(:value).present?
        end
        imgs
      end

      def images_collection
        @images_collection ||= absolutified_images
      end

      def absolutified_images
        parsed_images.map { |i| URL.absolutify(i, base_url, normalize: false) }
      end

      def parsed_images
        cleanup(parsed.search('//img/@src'))
      end

      def content_of(content)
        return nil if content.nil? || content.empty?
        content
      end
    end
  end
end
