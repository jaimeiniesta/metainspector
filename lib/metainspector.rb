require 'open-uri'
require 'rubygems'
require 'nokogiri'

# MetaInspector provides an easy way to scrape web pages and get its elements
class MetaInspector
  VERSION = '1.1.2'
  
  attr_reader :address, :title, :description, :keywords, :links, :full_doc, :scraped_doc
  
  # Initializes a new instance of MetaInspector, setting the URL address to the one given
  # TODO: validate address as http URL, dont initialize it if wrong format 
  def initialize(address)
    @address = address
    @scraped = false
    
    @title = @description = @keywords = @full_doc = @scraped_doc = nil
    @links = []
  end
  
  # Setter for address. Initializes the whole state as the address is being changed.
  def address=(address)
    initialize(address)
  end
  
  # Visit web page, get its contents, and parse it
  def scrape!
    @full_doc = open(@address)
    @scraped_doc = Nokogiri::HTML(@full_doc)
    
    # Searching title...
    @title = @scraped_doc.css('title').inner_html rescue nil
    
    # Searching meta description...
    @description = @scraped_doc.css("meta[@name='description']").first['content'] rescue nil
    
    # Searching meta keywords...
    @keywords = @scraped_doc.css("meta[@name='keywords']").first['content'] rescue nil
        
    # Searching links...
    @links = []
    @scraped_doc.search("//a").each do |link|
      @links << link.attributes["href"].to_s.strip
    end
    
    # Mark scraping as success
    @scraped = true

    rescue SocketError
      puts 'MetaInspector exception: The url provided does not exist or is temporarily unavailable (socket error)'
      @scraped = false
    rescue TimeoutError
      puts 'Timeout!!!'
    rescue
      puts 'An exception occurred while trying to scrape the page!'
  end
  
  # Syntactic sugar
  def scraped?
    @scraped
  end
end