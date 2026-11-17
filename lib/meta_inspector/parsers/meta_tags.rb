module MetaInspector
  module Parsers
    class MetaTagsParser < Base
      delegate :parsed => :@main_parser

      def meta_tags
        {
          'name'       => meta_tags_by('name'),
          'http-equiv' => meta_tags_by('http-equiv'),
          'property'   => meta_tags_by('property'),
          'charset'    => [charset_from_meta_charset]
        }
      end

      # Like meta_tags, with only the first value of each tag
      def meta_tag
        meta_tags.transform_values do |values|
          values.is_a?(Hash) ? values.transform_values(&:first) : values.first
        end
      end

      # meta_tag merged into one Hash: name, then http-equiv, then property
      def meta
        meta_tag['name']
          .merge(meta_tag['http-equiv'])
          .merge(meta_tag['property'])
          .merge('charset' => meta_tag['charset'])
      end

      # Returns the charset from the meta tags, searching in this order:
      # <meta charset='utf-8' />
      # <meta http-equiv="Content-Type" content="text/html; charset=windows-1252" />
      def charset
        @charset ||= (charset_from_meta_charset || charset_from_meta_content_type)
      end

      private

      def charset_from_meta_charset
        parsed.at_css('meta[charset]')&.attributes&.[]('charset')&.value
      end

      def charset_from_meta_content_type
        tag = parsed.css('meta[http-equiv]').find do |meta|
          meta['http-equiv'].casecmp('Content-Type').zero?
        end
        return unless tag

        tag['content'].to_s[/;\s*charset\s*=\s*["']?([^;\s"']+)/i, 1]
      end

      # Returns every content of the meta tags with that attribute, keyed by
      # its lowercased value
      def meta_tags_by(attribute)
        parsed.css("meta[@#{attribute}]").each_with_object({}) do |tag, contents|
          name    = tag.attributes[attribute]&.value&.downcase
          content = tag.attributes['content']&.value
          (contents[name] ||= []) << content if name && content
        end
      end
    end
  end
end
