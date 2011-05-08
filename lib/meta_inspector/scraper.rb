# -*- encoding: utf-8 -*-

require 'open-uri'
require 'rubygems'
require 'nokogiri'
require 'charguess'
require 'iconv'

# MetaInspector provides an easy way to scrape web pages and get its elements
module MetaInspector
  class Scraper
    attr_reader :address

    # Initializes a new instance of MetaInspector, setting the URL address to the one given
    # TODO: validate address as http URL, dont initialize it if wrong format
    def initialize(address)
      # rromanchuk: I added the most basic validation for missing schemes by assuming the client 
      # is using http if none is provided. Lack of scheme would cause a fatal. It's probably the  
      # clients responsibilty to validate this url but adding missing scheme would be a nice convienence 
      @address = URI.parse(address).scheme.nil? ? 'http://' + address : address
      @document = @title = @description = @keywords = @image = @links = nil
    end

    # Returns the parsed document title, from the content of the <title> tag.
    # This is not the same as the meta_tite tag
    def title
      @title ||= parsed_document.css('title').inner_html rescue nil
    end

    # Returns the parsed document links
    def links
      @links ||= parsed_document.search("//a").map {|link| link.attributes["href"].to_s.strip} rescue nil
    end
    
    # Returns the parsed image from Facebook's open graph property tags
    # Most all major websites now define this property and is usually very relevant
    def image
      @image ||= parsed_document.document.css("meta[@property='og:image']").first['content'] rescue nil
    end

    # Returns the charset
    # TODO: We should trust the charset expressed on the Content-Type meta tag
    # and only guess it if none given
    def charset
      @charset ||= CharGuess.guess(document).downcase
    end

    # Returns the whole parsed document
    def parsed_document
      @parsed_document ||= Nokogiri::HTML(document)

      rescue
        warn 'An exception occurred while trying to scrape the page!'
    end

    # Returns the original, unparsed document
    def document
      @document ||= open(@address).read

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
    # TODO: this should be case unsensitive, so meta_robots gets the results from the HTML for robots, Robots, ROBOTS...
    # TODO: cache results on instance variables, using ||=
    # TODO: define respond_to? to return true on the meta_name methods
    def method_missing(method_name)
      if method_name.to_s =~ /^meta_(.*)/
        content = parsed_document.css("meta[@name='#{$1}']").first['content'] rescue nil
        content = parsed_document.css("meta[@http-equiv='#{$1.gsub("_", "-")}']").first['content'] rescue nil if content.nil?          
        content
      else
        super
      end
    end
  end
end