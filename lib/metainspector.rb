require 'open-uri'
require 'rubygems'
require 'nokogiri'

# MetaInspector provides an easy way to scrape web pages and get its elements
class MetaInspector
  VERSION = '1.1.4'
  
  attr_reader :address
  
  # Initializes a new instance of MetaInspector, setting the URL address to the one given
  # TODO: validate address as http URL, dont initialize it if wrong format 
  def initialize(address)
    @address = address
    
    @document = @title = @description = @keywords = @links = nil
  end
  
  # Returns the parsed document title
  def title
    @title ||= document.css('title').inner_html rescue nil
  end
  
  # Returns the parsed document meta description
  def description
    @description ||= document.css("meta[@name='description']").first['content'] rescue nil
  end
  
  # Returns the parsed document meta keywords
  def keywords
    @keywords ||= document.css("meta[@name='keywords']").first['content'] rescue nil
  end
  
  # Returns the parsed document links
  def links
    @links ||= document.search("//a").map {|link| link.attributes["href"].to_s.strip} rescue nil
  end
  
  # Returns the parsed image from Facebook's open graph property tags
  # Most all major websites now define this property and is usually very relevant
  def image
    @image ||= document.css("meta[@property='og:image']").first['content'] rescue nil
  end
  
  # Returns the whole parsed document
  def document
    @document ||= Nokogiri::HTML(open(@address))
    
    rescue SocketError
      puts 'MetaInspector exception: The url provided does not exist or is temporarily unavailable (socket error)'
      @scraped = false
    rescue TimeoutError
      puts 'Timeout!!!'
    rescue
      puts 'An exception occurred while trying to scrape the page!'
  end

end