# -*- encoding: utf-8 -*-

require 'nokogiri'
require 'hashie/rash'

module MetaInspector
  # Parses the document with Nokogiri
  class Parser
    include MetaInspector::Exceptionable

    def initialize(document, options = {})
      options = defaults.merge(options)

      @document       = document
      @data           = Hashie::Rash.new
      @exception_log  = options[:exception_log]
    end

    extend Forwardable
    def_delegators :@document, :url, :scheme, :host

    # Returns the whole parsed document
    def parsed
      @parsed ||= Nokogiri::HTML(@document.to_s)

      rescue Exception => e
        @exception_log << e
    end

    def to_hash
      scrape_meta_data
      @data.to_hash
    end

    # Returns the parsed document title, from the content of the <title> tag.
    # This is not the same as the meta_title tag
    def title
      @title ||= parsed.css('title').inner_text rescue nil
    end

    # A description getter that first checks for a meta description and if not present will
    # guess by looking at the first paragraph with more than 120 characters
    def description
      meta_description || secondary_description
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
    def image
      meta_og_image || meta_twitter_image
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

    # Scrapers for all meta_tags in the form of "meta_name" are automatically defined. This has been tested for
    # meta name: keywords, description, robots, generator
    # meta http-equiv: content-language, Content-Type
    #
    # It will first try with meta name="..." and if nothing found,
    # with meta http-equiv="...", substituting "_" by "-"
    # TODO: define respond_to? to return true on the meta_name methods
    def method_missing(method_name)
      if method_name.to_s =~ /^meta_(.*)/
        key = $1

        #special treatment for opengraph (og:) and twitter card (twitter:) tags
        key.gsub!("_",":") if key =~ /^og_(.*)/ || key =~ /^twitter_(.*)/

        scrape_meta_data

        @data.meta.name && (@data.meta.name[key.downcase]) || (@data.meta.property && @data.meta.property[key.downcase])
      else
        super
      end
    end

    # Scrapes all meta tags found
    def scrape_meta_data
      unless @data.meta
        @data.meta!.name!
        @data.meta!.property!
        parsed.xpath("//meta").each do |element|
          get_meta_name_or_property(element)
        end
      end
    end

    # Store meta tag value, looking at meta name or meta property
    def get_meta_name_or_property(element)
      name_or_property = element.attributes["name"] ? "name" : (element.attributes["property"] ? "property" : nil)
      content_or_value = element.attributes["content"] ? "content" : (element.attributes["value"] ? "value" : nil)

      if !name_or_property.nil? && !content_or_value.nil?
        @data.meta.name[element.attributes[name_or_property].value.downcase] = element.attributes[content_or_value].value
      end
    end

    # Look for the first <p> block with 120 characters or more
    def secondary_description
      first_long_paragraph = parsed.search('//p[string-length() >= 120]').first
      first_long_paragraph ? first_long_paragraph.text : ''
    end

    def parsed_links
      @parsed_links ||= cleanup_nokogiri_values(parsed.search("//a/@href"))
    end

    def parsed_images
      @parsed_images ||= cleanup_nokogiri_values(parsed.search('//img/@src'))
    end

    def parsed_feed(format)
      feed = parsed.search("//link[@type='application/#{format}+xml']").first
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
      parsed.search('base').first.attributes['href'].value rescue nil
    end

    # Takes a nokogiri search result, strips the values, rejects the empty ones, and removes duplicates
    def cleanup_nokogiri_values(results)
      results.map { |a| a.value.strip }.reject { |s| s.empty? }.uniq
    end
  end
end
