# -*- encoding: utf-8 -*-

require 'nokogiri'

module MetaInspector
  # Parses the document with Nokogiri
  class Parser
    include MetaInspector::Exceptionable

    def initialize(document, options = {})
      options = defaults.merge(options)

      @document       = document
      @exception_log  = options[:exception_log]
    end

    extend Forwardable
    def_delegators :@document, :url, :scheme, :host

    def meta_tags
      {
        'name'        => meta_tags_by('name'),
        'http-equiv'  => meta_tags_by('http-equiv'),
        'property'    => meta_tags_by('property'),
        'charset'     => [charset_from_meta_charset]
      }
    end

    def meta_tag
      convert_each_array_to_first_element_on meta_tags
    end

    def meta
      meta_tag['name'].merge(meta_tag['http-equiv']).merge(meta_tag['property']).merge({'charset' => meta_tag['charset']})
    end

    # Returns the whole parsed document
    def parsed
      @parsed ||= Nokogiri::HTML(@document.to_s)

      rescue Exception => e
        @exception_log << e
    end

    # Returns the parsed document title, from the content of the <title> tag.
    # This is not the same as the meta_title tag
    def title
      @title ||= parsed.css('title').inner_text rescue nil
    end
    
    # Return favicon url if exist
    def favicon
      @favicon ||= URL.absolutify(parsed.xpath('//link[@rel="icon" or contains(@rel, "shortcut")]]')[0].attributes['href'].value, base_url) rescue nil
    end

    # A description getter that first checks for a meta description and if not present will
    # guess by looking at the first paragraph with more than 120 characters
    def description
      meta['description'] || secondary_description
    end

    # Links found on the page, as absolute URLs
    def links
      @links ||= parsed_links.map{ |l| URL.absolutify(URL.unrelativize(l, scheme), base_url) }.compact.uniq
    end

    # Internal links found on the page, as absolute URLs
    def internal_links
      @internal_links ||= links.select {|link| URL.new(link).host == host }
    end

    # External links found on the page, as absolute URLs
    def external_links
      @external_links ||= links.select {|link| URL.new(link).host != host }
    end

    # Images found on the page, as absolute URLs
    def images
      @images ||= parsed_images.map{ |i| URL.absolutify(i, base_url) }
    end

    # Returns the parsed image from Facebook's open graph property tags
    # Most all major websites now define this property and is usually very relevant
    # See doc at http://developers.facebook.com/docs/opengraph/
    # If none found, tries with Twitter image
    # TODO: if not found, try with images.first
    def image
      meta['og:image'] || meta['twitter:image']
    end

    # Returns the parsed document meta rss link
    def feed
      @feed ||= (parsed_feed('rss') || parsed_feed('atom'))
    end

    # Returns the charset from the meta tags, looking for it in the following order:
    # <meta charset='utf-8' />
    # <meta http-equiv="Content-Type" content="text/html; charset=windows-1252" />
    def charset
      @charset ||= (charset_from_meta_charset || charset_from_meta_content_type)
    end

    private

    def defaults
      { exception_log: MetaInspector::ExceptionLog.new }
    end

    def meta_tags_by(attribute)
      hash = {}
      parsed.css("meta[@#{attribute}]").map do |tag|
        name    = tag.attributes[attribute].value.downcase rescue nil
        content = tag.attributes['content'].value rescue nil

        if name && content
          hash[name] ||= []
          hash[name] << content
        end
      end
      hash
    end

    def convert_each_array_to_first_element_on(hash)
      hash.each_pair do |k, v|
        hash[k] = if v.is_a?(Hash)
          convert_each_array_to_first_element_on(v)
        elsif v.is_a?(Array)
          v.first
        else
          v
        end
      end
    end

    # Look for the first <p> block with 120 characters or more
    def secondary_description
      first_long_paragraph = parsed_search('//p[string-length() >= 120]').first
      first_long_paragraph ? first_long_paragraph.text : ''
    end

    def parsed_links
      @parsed_links ||= cleanup_nokogiri_values(parsed_search("//a/@href"))
    end

    def parsed_images
      @parsed_images ||= cleanup_nokogiri_values(parsed_search('//img/@src'))
    end

    def parsed_feed(format)
      feed = parsed_search("//link[@type='application/#{format}+xml']").first
      feed ? URL.absolutify(feed.attributes['href'].value, base_url) : nil
    end

    def charset_from_meta_charset
      parsed.css("meta[charset]")[0].attributes['charset'].value rescue nil
    end

    def charset_from_meta_content_type
      parsed.css("meta[http-equiv='Content-Type']")[0].attributes['content'].value.split(";")[1].split("=")[1] rescue nil
    end

    # Returns the base url to absolutify relative links. This can be the one set on a <base> tag,
    # or the url of the document if no <base> tag was found.
    def base_url
      base_href || url
    end

    # Returns the value of the href attribute on the <base /> tag, if it exists
    def base_href
      parsed_search('base').first.attributes['href'].value rescue nil
    end

    # Takes a nokogiri search result, strips the values, rejects the empty ones, and removes duplicates
    def cleanup_nokogiri_values(results)
      results.map { |a| a.value.strip }.reject { |s| s.empty? }.uniq
    end

    # Searches the parsed document for the selector, if the parsed document is searchable
    def parsed_search(selector)
      parsed.respond_to?(:search) ? parsed.search(selector) : []
    end
  end
end
