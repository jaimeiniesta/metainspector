require 'open-uri'
require 'rubygems'
require 'hpricot'

# MetaInspector provides an easy way to scrape web pages and get its elements
class MetaInspector
  VERSION = '1.1.0'

  Hpricot.buffer_size = 300000
  
  attr_reader :address, :title, :description, :keywords, :links, :full_doc, :scraped_doc
  
  # Initializes a new instance of MetaInspector, setting the URL address to the one given
  # TODO: validate address as http URL, dont initialize it if wrong format 
  def initialize(address)
    @address = address
    @scraped = false
    
    @title = @description = @keywords = @links = @full_doc = @scraped_doc = nil
  end
  
  # Setter for address. Initializes the whole state as the address is being changed.
  def address=(address)
    initialize(address)
  end
  
  # Visit web page, get its contents, and parse it
  def scrape!
    @full_doc = open(@address)
    @scraped_doc = Hpricot(@full_doc)
    
    # Searching title...
    if @scraped_doc.at('title')
      @title = @scraped_doc.at('title').inner_html.strip
    else
      @title = ""
    end
    
    # Searching meta description...
    if @scraped_doc.at("meta[@name='description']")
      @description = @scraped_doc.at("meta[@name='description']")['content'].strip
    else
      @description = ""
    end
    
    # Searching meta keywords...
    if @scraped_doc.at("meta[@name='keywords']")
      @keywords = @scraped_doc.at("meta[@name='keywords']")['content'].strip
    else
      @keywords = ""
    end
        
    # Searching links...
    @links = []
    @scraped_doc.search("//a").each do |link|
      @links << link.attributes["href"].strip if (!link.attributes["href"].nil?)
    end
    
    # Mark scraping as success
    @scraped = true

    rescue SocketError
      puts 'MetaInspector exception: The url provided does not exist or is temporarily unavailable (socket error)'
      @scraped = false
  end
  
  # Syntactic sugar
  def scraped?
    @scraped
  end
end