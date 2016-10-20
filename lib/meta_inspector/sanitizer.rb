require 'loofah'
require 'htmlentities'

module MetaInspector
  class Sanitizer
    def trim_whitespace(str)
      str.strip.gsub /\s\s+/, ' '
    end

    def unescape_html_entities(raw_html)
      htmlentities.decode(raw_html)
    end

    def scrub_html_tags(raw_html)
      fragment = if raw_html.is_a? Nokogiri::XML::Node
        reparent_node_content_to_loofah_document(raw_html)
      else
        Loofah.fragment(raw_html)
      end

      # remove unsafe tags and their content
      fragment.scrub!(:prune)

      # replace safe tags with ther content
      fragment.text
    end

    def reparent_node_content_to_loofah_document(node)
      return node if node.is_a?(Loofah::HTML::Document) || node.is_a?(Loofah::HTML::DocumentFragment)

      node = node.root if node.respond_to? :root

      doc = Loofah::HTML::Document.new
      doc.encoding = node.document.encoding

      fragment = doc.fragment

      fragment.add_child node.dup.children

      fragment
    end

    def enforce_utf8_encoding(str)
      # we need utf-8 for further processing
      str.encode('utf-8')
    end

    def sanitize(raw_html)
      return nil unless raw_html

      sanitizer_methods = [
          :scrub_html_tags,
          :enforce_utf8_encoding,
          :unescape_html_entities,
          :trim_whitespace,
        ]
      sanitizer_methods.inject(raw_html) { |str, method| send method, str }
    end

    private

    def htmlentities
      @htmlentities ||= HTMLEntities.new
    end
  end
end
