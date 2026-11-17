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
        @inline_image_data = options[:inline_image_data]
        @image_sizes = {}
        @image_metadata = {}
        @download_attempts = 0
        super(main_parser)
      end

      def images
        self
      end

      # Returns the Facebook Open Graph image, Twitter image, Parsely image or
      # the largest image in the image collection
      def best
        suggested_image(skip_inline: !@inline_image_data) || largest
      end

      # Returns the parsed image from Facebook's open graph property tags
      # Most major websites now define this property and is usually relevant
      # See doc at http://developers.facebook.com/docs/opengraph/
      # If none found, tries with Twitter image, then Parsely image
      def owner_suggested
        result_url(suggested_image)
      end

      # Returns validity for each image URL; nil means no lookup was performed.
      def with_metadata
        absolutified_images.map do |url|
          { url: result_url(url), valid: @fetch_all_image_meta && url ? image_validity(url) : nil }
        end
      end

      # Returns an array of [img_url, width, height] sorted by image area (width * height),
      # ranking one candidate per <img> or <picture> (see ranked_candidates).
      def with_size
        @with_size ||= begin
          imgs_with_size = unique_image_candidates(ranked_candidates)
          if @download_images && @reject_invalid_images
            imgs_with_size.reject! { |url, width, height| image_validity(url) == false }
          end
          imgs_with_size.map! do |url, width, height|
            if width.nil? || height.nil?
              width, height = image_size(url) || [0, 0]
            end
            [result_url(url), width.to_i, height.to_i]
          end
          imgs_with_size.sort_by { |url, width, height| -(width.to_i * height.to_i) }
        end
      end

      # Returns image details sorted by area. Metadata lookups are opt-in.
      # With validation enabled, details reuse the validation lookups.
      def with_details
        @with_details ||= begin
          attempts = 0
          images = unique_image_candidates(image_candidates).filter_map do |url, width, height|
            metadata = nil
            if validating_images?
              next if @reject_invalid_images && image_validity(url) == false

              metadata = image_metadata(url)
            elsif @download_images
              if data_image_url?(url)
                metadata = image_metadata(url)
              elsif http_image_url?(url) && (@max_image_downloads.nil? || attempts < @max_image_downloads)
                attempts += 1
                metadata = @image_downloader.metadata(encoded_url(url))
              end
            end
            downloaded_width, downloaded_height = metadata && metadata[:dimensions]
            width ||= downloaded_width
            height ||= downloaded_height
            { url: result_url(url), width: width.to_i, height: height.to_i,
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
            (@inline_image_data || !data_image_url?(url)) && ratio > 0.1 && ratio < 10
          end
          url, width, height = imgs_with_size.first
          url
        end
      end

      # Return favicon url if exist
      def favicon
        link = parsed.xpath('//link[@rel]').find do |node|
          # Keep legacy shortcut-only links while matching whole, ASCII-insensitive tokens.
          node['rel'].tr('A-Z', 'a-z').split(/[ \t\n\f\r]+/).any? { |rel| rel == 'icon' || rel == 'shortcut' }
        end
        value = link.attributes['href'].value
        @favicon ||= result_url(URL.absolutify(value, base_url, normalize: false))
      rescue
        nil
      end

      private

      def result_url(url)
        return url if url.nil? || @inline_image_data || !data_image_url?(url)

        url.split(',', 2).first
      end

      def suggested_image(skip_inline: false)
        ['og:image', 'twitter:image', 'parsely-image-url'].each do |key|
          value = content_of(meta[key])
          next unless value

          url = URL.absolutify(value, base_url, normalize: false)
          next if url.nil? || (skip_inline && data_image_url?(url))
          next if @download_images && @reject_invalid_images && image_validity(url) == false

          return url
        end
        nil
      end

      def unique_image_candidates(list)
        candidates = {}
        list.each do |url, width, height|
          next if url.nil? || url.empty?

          previous = candidates[url]
          if previous.nil? || ((previous[1].nil? || previous[2].nil?) && width && height)
            candidates[url] = [url, width, height]
          end
        end
        candidates.values
      end

      # The candidates of one <img> or <picture> are the same picture at different
      # sizes, so only the largest one is downloaded for ranking: the largest width
      # descriptor if any candidate has one, otherwise the highest density (src
      # counts as 1x). Candidates that can't be measured are skipped while others
      # remain. A src with both dimensions in the HTML is kept too, as it costs no
      # download.
      def ranked_candidates
        image_candidates.group_by { |candidate| candidate[3] }.flat_map do |_group, candidates|
          candidates = candidates.reject { |url, *| url.nil? || url.empty? }
          sized = candidates.select { |_url, width, height| width && height }
          pool = candidates.select { |url, *| measurable_image_url?(url) }
          pool = candidates if pool.empty?
          with_width = pool.select { |candidate| candidate[4][0] == :w }
          pool = with_width unless with_width.empty?
          largest = pool.each_with_index.max_by { |candidate, index| [candidate[4][1], -index] }&.first
          largest ? [largest] + (sized - [largest]) : sized
        end
      end

      def measurable_image_url?(url)
        data_image_url?(url) ? @inline_image_data : http_image_url?(url)
      end

      def images_collection
        @images_collection ||= if @download_images && @reject_invalid_images
          absolutified_images.reject { |url| url && image_validity(url) == false }.map { |url| result_url(url) }
        else
          absolutified_images.map { |url| result_url(url) }
        end
      end

      def image_size(url)
        return @image_sizes[url] if @image_sizes.key?(url)
        return nil unless @download_images

        if data_image_url?(url)
          metadata = @image_downloader.inline_metadata(url)
          @image_metadata[url] = metadata
          return @image_sizes[url] = metadata && metadata[:dimensions]
        end
        return @image_sizes[url] = nil unless http_image_url?(url)
        return nil unless @max_image_downloads.nil? || @download_attempts < @max_image_downloads

        unless validating_images?
          @download_attempts += 1
          return @image_sizes[url] = @image_downloader.size(encoded_url(url))
        end

        request_url = encoded_url(url)
        @download_attempts += 1
        # Metadata comes from the same download and lets with_details reuse it.
        metadata = @image_downloader.metadata(request_url, reject_invalid_url: true)
        @image_metadata[url] = metadata
        @image_sizes[url] = metadata && metadata[:dimensions]
      end

      def image_metadata(url)
        image_size(url)
        @image_metadata[url]
      end

      def validating_images?
        @reject_invalid_images || @fetch_all_image_meta
      end

      # Normalizes non-ASCII URLs for the request; results keep the original.
      # A URL that cannot be normalized is returned as is, so URL validation
      # rejects it instead of Addressable raising.
      def encoded_url(url)
        url.ascii_only? ? url : URL.new(url).url
      rescue StandardError
        url
      end

      def image_validity(url)
        image_size(url)
        return nil unless @image_sizes.key?(url)

        !@image_sizes[url].nil?
      end

      def data_image_url?(url)
        url.match?(/\Adata:/i)
      end

      def http_image_url?(url)
        URLPolicy.validate!(encoded_url(url))
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
          candidates << [src, node['width'], node['height'], [:x, 1.0]] if src && !src.empty?
          srcset_urls(node['srcset']).each { |url, descriptor| candidates << [url, nil, nil, descriptor] }
          group = node.parent&.name == 'picture' ? node.parent.pointer_id : node.pointer_id
          candidates.map do |url, width, height, descriptor|
            [URL.absolutify(url, base_url, normalize: false), width, height, group, descriptor]
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
          parsed_descriptor = parse_srcset_descriptor(descriptor)
          urls << [url, parsed_descriptor] if !url.empty? && parsed_descriptor
        end
        urls
      end

      # Returns [:w, width] or [:x, density], or nil for an invalid descriptor.
      # A candidate without a descriptor is 1x.
      def parse_srcset_descriptor(descriptor)
        if descriptor.empty?
          [:x, 1.0]
        elsif descriptor.match?(/\A\d+w\z/) && descriptor.to_i > 0
          [:w, descriptor.to_i]
        elsif descriptor.match?(/\A(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?x\z/) && descriptor.to_f >= 0
          [:x, descriptor.to_f]
        end
      end

      def content_of(content)
        return nil if content.nil? || content.strip.empty?
        content
      end
    end
  end
end
