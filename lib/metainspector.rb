require 'open-uri'
require 'rubygems'
require 'nokogiri'
require 'UniversalDetector'
require 'iconv'

# MetaInspector provides an easy way to scrape web pages and get its elements
class MetaInspector
  VERSION = '1.1.5'
  
  attr_reader :address
  
  # Initializes a new instance of MetaInspector, setting the URL address to the one given
  # TODO: validate address as http URL, dont initialize it if wrong format 
  def initialize(address)
    @address = address
    
    @document = @title = @description = @keywords = @links = nil
  end
  
  # Returns the parsed document title
  def title
    @title ||= charset == 'utf-8' ? parsed_document.css('title').inner_html : Iconv.iconv('utf-8', charset, parsed_document.css('title').inner_html).to_s rescue nil
  end
  
  # Returns the parsed document meta description
  def description
    @description ||= charset == 'utf-8' ? parsed_document.css("meta[@name='description']").first['content'] : Iconv.iconv('utf-8', charset, parsed_document.css("meta[@name='description']").first['content']).to_s rescue nil
  end
  
  # Returns the parsed document meta keywords
  def keywords
    @keywords ||= charset == 'utf-8' ? parsed_document.css("meta[@name='keywords']").first['content'] : Iconv.iconv('utf-8', charset, parsed_document.css("meta[@name='keywords']").first['content']).to_s rescue nil
  end
  
  # Returns the parsed document links
  def links
    @links ||= parsed_document.search("//a").map {|link| link.attributes["href"].to_s.strip} rescue nil
  end
  
  # Returns the specified charset, or tries to guess it
  def charset
    @charset ||= UniversalDetector::chardet(document)['encoding'].downcase
  end
  
  # Returns the whole parsed document
  def parsed_document
    @parsed_document ||= Nokogiri::HTML(document)
    
    rescue
      puts 'An exception occurred while trying to scrape the page!'
  end
  
  # Returns the original, unparsed document
  def document
    @document ||= open(@address).read
    
    rescue SocketError
      puts 'MetaInspector exception: The url provided does not exist or is temporarily unavailable (socket error)'
      @scraped = false
    rescue TimeoutError
      puts 'Timeout!!!'
    rescue
      puts 'An exception occurred while trying to fetch the page!'
  end

end