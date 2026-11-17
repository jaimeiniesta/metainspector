require_relative '../image_downloader'
require 'strscan'

module MetaInspector
  module Parsers
    class ImagesParser < Base
      delegate [:parsed, :meta, :base_url]         => :@main_parser
      delegate [:each, :length, :size, :[], :last] => :images_collection

      include Enumerable

      # Meta tags that name the page's image, in order of preference.
      SUGGESTED_IMAGE_META = %w[og:image twitter:image parsely-image-url].freeze

      # A URL that an <img> or <picture> may show. group identifies that
      # element, and descriptor is [:w, width] or [:x, density].
      Candidate = Struct.new(:url, :width, :height, :group, :descriptor) do
        def width_descriptor?
          descriptor[0] == :w
        end

        def descriptor_value
          descriptor[1]
        end
      end
      private_constant :SUGGESTED_IMAGE_META, :Candidate

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
          candidates = unique_image_candidates(ranked_candidates)
          candidates.reject! { |candidate| image_validity(candidate.url) == false } if rejecting_invalid_images?
          images = candidates.map do |candidate|
            width, height = candidate.width, candidate.height
            width, height = image_size(candidate.url) || [0, 0] if width.nil? || height.nil?
            [result_url(candidate.url), width.to_i, height.to_i]
          end
          images.sort_by { |_url, width, height| -(width * height) }
        end
      end

      # Returns image details sorted by area. Metadata lookups are opt-in.
      # With validation enabled, details reuse the validation lookups.
      def with_details
        @with_details ||= begin
          downloads = 0
          images = unique_image_candidates(image_candidates).filter_map do |candidate|
            url = candidate.url
            metadata = nil
            if validating_images?
              next if @reject_invalid_images && image_validity(url) == false

              metadata = image_metadata(url)
            elsif @download_images
              if data_image_url?(url)
                metadata = image_metadata(url)
              elsif http_image_url?(url) && within_download_limit?(downloads)
                downloads += 1
                metadata = @image_downloader.metadata(encoded_url(url))
              end
            end
            downloaded_width, downloaded_height = metadata && metadata[:dimensions]
            { url: result_url(url),
              width: (candidate.width || downloaded_width).to_i,
              height: (candidate.height || downloaded_height).to_i,
              type: metadata && metadata[:type],
              file_size: metadata && metadata[:file_size] }
          end
          images.sort_by { |image| -(image[:width] * image[:height]) }
        end
      end

      # Returns the largest image from the image collection,
      # filtered for images that are more square than 10:1 or 1:10
      def largest
        @largest_image ||= with_size.find do |url, width, height|
          ratio = width.to_f / height.to_f
          (@inline_image_data || !data_image_url?(url)) && ratio > 0.1 && ratio < 10
        end&.first
      end

      # Return favicon url if exist. An href that can't be resolved returns nil.
      def favicon
        link = parsed.xpath('//link[@rel]').find do |node|
          # Keep legacy shortcut-only links while matching whole, ASCII-insensitive tokens.
          rel_tokens(node['rel']).any? { |rel| rel == 'icon' || rel == 'shortcut' }
        end
        result_url(URL.absolutify(link.attributes['href'].value, base_url, normalize: false))
      rescue StandardError
        nil
      end

      private

      def result_url(url)
        return url if url.nil? || @inline_image_data || !data_image_url?(url)

        url.split(',', 2).first
      end

      def suggested_image(skip_inline: false)
        SUGGESTED_IMAGE_META.each do |key|
          value = meta[key]
          next if value.nil? || value.strip.empty?

          url = URL.absolutify(value, base_url, normalize: false)
          next if url.nil? || (skip_inline && data_image_url?(url))
          next if rejecting_invalid_images? && image_validity(url) == false

          return url
        end
        nil
      end

      # Keeps one candidate per URL: the first one, unless a later one has both
      # dimensions in the HTML and the first doesn't.
      def unique_image_candidates(candidates)
        unique = {}
        candidates.each do |candidate|
          url = candidate.url
          next if url.nil? || url.empty?

          previous = unique[url]
          if previous.nil? || ((previous.width.nil? || previous.height.nil?) && candidate.width && candidate.height)
            unique[url] = candidate
          end
        end
        unique.values
      end

      # The candidates of one <img> or <picture> are the same picture at different
      # sizes, so only the largest one is downloaded for ranking: the largest width
      # descriptor if any candidate has one, otherwise the highest density (src
      # counts as 1x). Candidates that can't be measured are skipped while others
      # remain. A src with both dimensions in the HTML is kept too, as it costs no
      # download.
      def ranked_candidates
        image_candidates.group_by(&:group).flat_map do |_group, candidates|
          candidates = candidates.reject { |candidate| candidate.url.nil? || candidate.url.empty? }
          sized = candidates.select { |candidate| candidate.width && candidate.height }
          pool = candidates.select { |candidate| measurable_image_url?(candidate.url) }
          pool = candidates if pool.empty?
          with_width = pool.select(&:width_descriptor?)
          pool = with_width unless with_width.empty?
          largest = pool.each_with_index.max_by { |candidate, index| [candidate.descriptor_value, -index] }&.first
          largest ? [largest] + (sized - [largest]) : sized
        end
      end

      def measurable_image_url?(url)
        data_image_url?(url) ? @inline_image_data : http_image_url?(url)
      end

      def images_collection
        @images_collection ||= begin
          urls = absolutified_images
          urls = urls.reject { |url| url && image_validity(url) == false } if rejecting_invalid_images?
          urls.map { |url| result_url(url) }
        end
      end

      # Returns [width, height], or nil if unknown. Each URL is looked up once,
      # and only max_image_downloads HTTP lookups are made.
      def image_size(url)
        return @image_sizes[url] if @image_sizes.key?(url)
        return nil unless @download_images

        if data_image_url?(url)
          metadata = @image_downloader.inline_metadata(url)
          @image_metadata[url] = metadata
          return @image_sizes[url] = metadata && metadata[:dimensions]
        end
        return @image_sizes[url] = nil unless http_image_url?(url)
        return nil unless within_download_limit?(@download_attempts)

        @download_attempts += 1
        request_url = encoded_url(url)
        return @image_sizes[url] = @image_downloader.size(request_url) unless validating_images?

        # Metadata comes from the same download and lets with_details reuse it.
        metadata = @image_downloader.metadata(request_url, reject_invalid_url: true)
        @image_metadata[url] = metadata
        @image_sizes[url] = metadata && metadata[:dimensions]
      end

      def image_metadata(url)
        image_size(url)
        @image_metadata[url]
      end

      def within_download_limit?(downloads)
        @max_image_downloads.nil? || downloads < @max_image_downloads
      end

      def validating_images?
        @reject_invalid_images || @fetch_all_image_meta
      end

      def rejecting_invalid_images?
        @download_images && @reject_invalid_images
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
        image_candidates.map(&:url).uniq
      end

      # The src of each <img>, as 1x, and the srcset candidates of each <img>
      # and <picture> source, in document order.
      def image_candidates
        @image_candidates ||= parsed.xpath('//img | //picture/source').flat_map do |node|
          sources = []
          src = node['src'].to_s.strip if node.name == 'img'
          sources << [src, node['width'], node['height'], [:x, 1.0]] if src && !src.empty?
          srcset_urls(node['srcset']).each { |url, descriptor| sources << [url, nil, nil, descriptor] }
          group = node.parent&.name == 'picture' ? node.parent.pointer_id : node.pointer_id
          sources.map do |url, width, height, descriptor|
            Candidate.new(URL.absolutify(url, base_url, normalize: false), width, height, group, descriptor)
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
    end
  end
end
