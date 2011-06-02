# -*- encoding: utf-8 -*-

require 'open-uri'
require 'rubygems'
require 'nokogiri'
require 'charguess'
require 'iconv'
require 'hashie/rash'

# MetaInspector provides an easy way to scrape web pages and get its elements
module MetaInspector
  class Scraper
    attr_reader :url
    # Initializes a new instance of MetaInspector, setting the URL to the one given
    # If no scheme given, set it to http:// by default
    def initialize(url)
      @url = URI.parse(url).scheme.nil? ? 'http://' + url : url
      @data = Hashie::Rash.new('url' => @url)
    end

    # Returns the parsed document title, from the content of the <title> tag.
    # This is not the same as the meta_tite tag
    def title
      @data.title ||= parsed_document.css('title').inner_html rescue nil
    end

    # Returns the parsed document links
    def links
      @data.links ||= remove_mailto(parsed_document.search("//a") \
                                .map {|link| link.attributes["href"] \
                                .to_s.strip}.uniq) rescue nil
    end

    # Returns the links converted to absolute urls
    def absolute_links
      @data.absolute_links ||= links.map { |l| absolutify_url(l) }
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

    # Returns the charset
    # TODO: We should trust the charset expressed on the Content-Type meta tag
    # and only guess it if none given
    def charset
      @data.charset ||= CharGuess.guess(document).downcase
    end

    # Returns all parsed data as a nested Hash
    def to_hash
      # TODO: find a better option to populate the data to the Hash
      image;feed;links;charset;absolute_links;title;meta_keywords
      @data.to_hash
    end

    # Returns the whole parsed document
    def parsed_document
      @parsed_document ||= Nokogiri::HTML(document)

      rescue
        warn 'An exception occurred while trying to scrape the page!'
    end

    # Returns the original, unparsed document
    def document
      @document ||= open(@url).read

      rescue SocketError
        warn 'MetaInspector exception: The url provided does not exist or is temporarily unavailable (socket error)'
        @scraped = false
      rescue TimeoutError
        warn 'Timeout!!!'
      rescue
        warn 'An exception occurred while trying to fetch the page!'
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
          parsed_document.xpath("//meta").each { |element|
            @data.meta.name[element.attributes["name"].value.downcase] = element.attributes["content"].value if element.attributes["name"]
            @data.meta.property[element.attributes["property"].value.downcase] = element.attributes["content"].value if element.attributes["property"]
          }
        end
        @data.meta.name && (@data.meta.name[key.downcase]) || (@data.meta.property && @data.meta.property[key.downcase])
      else
        super
      end
    end

    private

    # Convert a relative url like "/users" to an absolute one like "http://example.com/users"
    def absolutify_url(url)
      url =~ /^http.*/ ? url : File.join(@url,url)
    end

    # Remove mailto links
    # TODO: convert this to a more generic filter to remove all non-http[s] like ftp, telnet, etc.
    def remove_mailto(links)
      links.reject {|l| l.index('mailto')}
    end
  end
end