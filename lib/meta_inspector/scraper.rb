# -*- encoding: utf-8 -*-

require 'open-uri'
require 'nokogiri'
require 'hashie/rash'
require 'timeout'

# MetaInspector provides an easy way to scrape web pages and get its elements
module MetaInspector
  class Scraper
    attr_reader :url, :scheme, :host, :root_url, :errors, :content_type

    # Initializes a new instance of MetaInspector, setting the URL to the one given
    # If no scheme given, set it to http:// by default
    # Options:
    # => timeout: defaults to 20 seconds
    # => html_content_type_only: if an exception should be raised if request content-type is not text/html. Defaults to false
    def initialize(url, options = {})
      url       = encode_url(url)
      @url      = URI.parse(url).scheme.nil? ? 'http://' + url : url
      @scheme   = URI.parse(@url).scheme
      @host     = URI.parse(@url).host
      @root_url = "#{@scheme}://#{@host}/"
      @timeout  = options[:timeout] || 20
      @data     = Hashie::Rash.new('url' => @url)
      @errors   = []
      @html_content_only = options[:html_content_only] || false
    end

    # Returns the parsed document title, from the content of the <title> tag.
    # This is not the same as the meta_tite tag
    def title
      @data.title ||= parsed_document.css('title').inner_html.gsub(/\t|\n|\r/, '') rescue nil
    end

    # A description getter that first checks for a meta description and if not present will
    # guess by looking grabbing the first paragraph > 120 characters
    def description
      meta_description.nil? ? secondary_description : meta_description
    end

    # Links found on the page, as absolute URLs
    def links
      @data.links ||= parsed_links.map{ |l| absolutify_url(unrelativize_url(l)) }.compact
    end

    # Internal links found on the page, as absolute URLs
    def internal_links
      @data.internal_links ||= links.select {|link| URI.parse(link).host == @host }
    end

    # External links found on the page, as absolute URLs
    def external_links
      @data.external_links ||= links.select {|link| URI.parse(link).host != @host }
    end

    # Images found on the page, as absolute URLs
    def images
      @data.images ||= parsed_images.map{ |i| absolutify_url(i) }
    end

    # Returns the parsed document meta rss links
    def feed
      @data.feed ||= parsed_document.xpath("//link").select{ |link|
          link.attributes["type"] && link.attributes["type"].value =~ /(atom|rss)/
        }.map { |link|
          absolutify_url(link.attributes["href"].value)
        }.first rescue nil
    end

    # Returns the parsed image from Facebook's open graph property tags
    # Most all major websites now define this property and is usually very relevant
    # See doc at http://developers.facebook.com/docs/opengraph/
    def image
      meta_og_image
    end

    # Returns the charset from the meta tags, looking for it in the following order:
    # <meta charset='utf-8' />
    # <meta http-equiv="Content-Type" content="text/html; charset=windows-1252" />
    def charset
      @data.charset ||= (charset_from_meta_charset || charset_from_content_type)
    end

    # Returns all parsed data as a nested Hash
    def to_hash
      # TODO: find a better option to populate the data to the Hash
      image;images;feed;links;charset;title;meta_keywords;internal_links;external_links
      @data.to_hash
    end

    # Returns true if parsing has been successful
    def parsed?
      !@parsed_document.nil?
    end

    # Returns the whole parsed document
    def parsed_document
      @parsed_document ||= Nokogiri::HTML(document)
      rescue Exception => e
        add_fatal_error "Parsing exception: #{e.message}"
    end

    # Returns the original, unparsed document
    def document
      @document ||= Timeout::timeout(@timeout) {
        req = open(@url)
        @content_type = @data.content_type = req.content_type

        if @html_content_only && @content_type != "text/html"
           raise "The url provided contains #{@content_type} content instead of text/html content"
        end

        req.read
      }

      rescue SocketError
        add_fatal_error 'Socket error: The url provided does not exist or is temporarily unavailable'
      rescue TimeoutError
        add_fatal_error 'Timeout!!!'
      rescue Exception => e
        add_fatal_error "Scraping exception: #{e.message}"
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
        #special treatment for og:
        if key =~ /^og_(.*)/
          key = "og:#{$1}"
        end
        unless @data.meta
          @data.meta!.name!
          @data.meta!.property!
          parsed_document.xpath("//meta").each do |element|
            if element.attributes["content"]
              if element.attributes["name"]
                @data.meta.name[element.attributes["name"].value.downcase] = element.attributes["content"].value
              end

              if element.attributes["property"]
                @data.meta.property[element.attributes["property"].value.downcase] = element.attributes["content"].value
              end
            end
          end
        end
        @data.meta.name && (@data.meta.name[key.downcase]) || (@data.meta.property && @data.meta.property[key.downcase])
      else
        super
      end
    end

    private

    def parsed_links
      @parsed_links ||= parsed_document.search("//a") \
                        .map {|link| link.attributes["href"] \
                        .to_s.strip}.uniq rescue []
    end

    def parsed_images
      @parsed_images ||= parsed_document.search('//img') \
                                        .reject{|i| (i.attributes['src'].nil? || i.attributes['src'].value.empty?) } \
                                        .map{ |i| i.attributes['src'].value }.uniq
    end

    # Stores the error for later inspection
    def add_fatal_error(error)
      warn error
      @errors << error
    end

    # Encode url to deal with international characters
    def encode_url(url)
      URI.encode(url).to_s.gsub("%23", "#")
    end

    # Convert a relative url like "/users" to an absolute one like "http://example.com/users"
    # Respecting already absolute URLs like the ones starting with http:, ftp:, telnet:, mailto:, javascript: ...
    def absolutify_url(url)
      if url =~ /^\w*\:/i
        encode_url(url)
      else
        URI.parse(@root_url).merge(encode_url(url)).to_s
      end
    rescue URI::InvalidURIError => e
      add_fatal_error "Link parsing exception: #{e.message}" and nil
    end

    # Convert a protocol-relative url to its full form, depending on the scheme of the page that contains it
    def unrelativize_url(url)
      url =~ /^\/\// ? "#{scheme}://#{url[2..-1]}" : url
    end

    # Look for the first <p> block with 120 characters or more
    def secondary_description
      (p = parsed_document.search('//p').map(&:text).select{ |p| p.length > 120 }.first).nil? ? '' : p
    end

    def charset_from_meta_charset
      parsed_document.css("meta[charset]")[0].attributes['charset'].value rescue nil
    end

    def charset_from_content_type
      parsed_document.css("meta[http-equiv='Content-Type']")[0].attributes['content'].value.split(";")[1].split("=")[1] rescue nil
    end
  end
end