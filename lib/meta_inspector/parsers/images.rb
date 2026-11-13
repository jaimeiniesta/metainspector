require_relative '../image_downloader'
require 'strscan'

module MetaInspector
  module Parsers
    class ImagesParser < Base
      delegate [:parsed, :meta, :base_url]         => :@main_parser
      delegate [:each, :length, :size, :[], :last] => :images_collection

      include Enumerable

      def initialize(main_parser, options = {})
        @image_downloader = options[:image_downloader]
        @download_images = options[:download_images]
        @max_image_downloads = options[:max_image_downloads]
        @reject_invalid_images = (options[:download_image_options] || {})[:reject_invalid_images]
        @fetch_all_image_meta = options[:fetch_all_image_meta]
        @image_sizes = {}
        @download_attempts = 0
        super(main_parser)
      end

      def images
        self
      end

      # Returns the Facebook Open Graph image, Twitter image, Parsely image or
      # the largest image in the image collection
      def best
        owner_suggested || largest
      end

      # Returns the parsed image from Facebook's open graph property tags
      # Most major websites now define this property and is usually relevant
      # See doc at http://developers.facebook.com/docs/opengraph/
      # If none found, tries with Twitter image, then Parsely image
      def owner_suggested
        if @download_images && @reject_invalid_images
          ['og:image', 'twitter:image', 'parsely-image-url'].each do |key|
            value = content_of(meta[key])
            url = URL.absolutify(value, base_url, normalize: false) if value
            return url if url && image_validity(url) != false
          end
          return nil
        end
        suggested_img = content_of(meta['og:image']) || content_of(meta['twitter:image']) ||
                        content_of(meta['parsely-image-url'])
        URL.absolutify(suggested_img, base_url, normalize: false) if suggested_img
      end

      # Returns validity for each image URL; nil means no lookup was performed.
      def with_metadata
        absolutified_images.map do |url|
          { url: url, valid: @fetch_all_image_meta && url ? image_validity(url) : nil }
        end
      end

      # Returns an array of [img_url, width, height] sorted by image area (width * height)
      def with_size
        @with_size ||= begin
          imgs_with_size = unique_image_candidates
          if @download_images && @reject_invalid_images
            imgs_with_size.reject! { |url, width, height| image_validity(url) == false }
          end
          imgs_with_size.map! do |url, width, height, responsive|
            if width.nil? || height.nil?
              unfetchable = responsive && !@reject_invalid_images && !@fetch_all_image_meta && !http_image_url?(url)
              width, height = (image_size(url) unless unfetchable) || [0, 0]
            end
            [url, width.to_i, height.to_i]
          end
          imgs_with_size.sort_by { |url, width, height| -(width.to_i * height.to_i) }
        end
      end

      # Returns image details sorted by area. Metadata lookups are opt-in.
      def with_details
        @with_details ||= begin
          images = unique_image_candidates
          attempts = 0
          images.map! do |url, width, height, responsive|
            metadata = nil
            fetchable = !responsive || http_image_url?(url)
            if fetchable && @download_images && (@max_image_downloads.nil? || attempts < @max_image_downloads)
              attempts += 1
              metadata = @image_downloader.metadata(url)
            end
            downloaded_width, downloaded_height = metadata && metadata[:dimensions]
            width ||= downloaded_width
            height ||= downloaded_height
            { url: url, width: width.to_i, height: height.to_i,
              type: metadata && metadata[:type], file_size: metadata && metadata[:file_size] }
          end
          images.sort_by { |image| -(image[:width] * image[:height]) }
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

      def unique_image_candidates
        candidates = {}
        image_candidates.each do |url, width, height, responsive|
          next if url.nil? || url.empty?

          previous = candidates[url]
          if previous.nil? || ((previous[1].nil? || previous[2].nil?) && width && height)
            candidates[url] = [url, width, height, responsive]
          end
        end
        candidates.values
      end

      def images_collection
        @images_collection ||= if @download_images && @reject_invalid_images
          absolutified_images.reject { |url| url && image_validity(url) == false }
        else
          absolutified_images
        end
      end

      def image_size(url)
        return @image_sizes[url] if @image_sizes.key?(url)
        return nil unless @download_images && (@max_image_downloads.nil? || @download_attempts < @max_image_downloads)

        @download_attempts += 1
        if @reject_invalid_images || @fetch_all_image_meta
          begin
            URLPolicy.validate!(url)
          rescue MetaInspector::RequestError
            return @image_sizes[url] = nil
          end
        end
        @image_sizes[url] = if @reject_invalid_images || @fetch_all_image_meta
          @image_downloader.size(url, reject_invalid_url: true)
        else
          @image_downloader.size(url)
        end
      end

      def image_validity(url)
        image_size(url)
        return nil unless @image_sizes.key?(url)

        !@image_sizes[url].nil?
      end

      def http_image_url?(url)
        URLPolicy.validate!(url)
        true
      rescue URLPolicy::InvalidURL
        false
      end

      def absolutified_images
        image_candidates.map(&:first).uniq
      end

      def image_candidates
        @image_candidates ||= parsed.xpath('//img | //picture/source').flat_map do |node|
          candidates = []
          src = node['src'].to_s.strip if node.name == 'img'
          candidates << [src, node['width'], node['height']] if src && !src.empty?
          srcset_urls(node['srcset']).each { |url| candidates << [url, nil, nil, true] }
          candidates.map do |url, width, height, responsive|
            [URL.absolutify(url, base_url, normalize: false), width, height, responsive]
          end
        end
      end

      def srcset_urls(value)
        scanner = StringScanner.new(value.to_s)
        urls = []
        until scanner.eos?
          scanner.skip(/[\t\n\f\r ,]+/)
          break if scanner.eos?

          url = scanner.scan(/[^\t\n\f\r ]+/)
          if url.end_with?(',')
            url = url.sub(/,+\z/, '')
            descriptor = ''
          else
            scanner.skip(/[\t\n\f\r ]+/)
            descriptor = scanner.scan(/(?:[^,(]|\([^)]*(?:\)|\z))*/).strip
            scanner.skip(/,/)
          end
          urls << url if !url.empty? && valid_srcset_descriptor?(descriptor)
        end
        urls
      end

      def valid_srcset_descriptor?(descriptor)
        descriptor.empty? || (descriptor.match?(/\A\d+w\z/) && descriptor.to_i > 0) ||
          (descriptor.match?(/\A(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?x\z/) && descriptor.to_f >= 0)
      end

      def content_of(content)
        return nil if content.nil? || content.strip.empty?
        content
      end
    end
  end
end
