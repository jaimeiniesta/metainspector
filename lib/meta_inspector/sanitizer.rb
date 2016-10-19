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
      fragment = Loofah.fragment(raw_html)

      # remove unsafe tags and their content
      fragment.scrub!(:prune)

      # replace safe tags with ther content
      fragment.text
    end

    def enforce_utf8_encoding(str)
      # we need utf-8 for further processing
      str.encode('utf-8')
    end

    def sanitize(raw_html)
      return nil unless raw_html

      sanitizer_methods = [
          :enforce_utf8_encoding,
          :scrub_html_tags,
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
