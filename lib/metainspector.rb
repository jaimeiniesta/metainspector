class MetaInspector
  require 'open-uri'
  require 'rubygems'
  require 'hpricot'

  Hpricot.buffer_size = 300000

  def self.scrape(url)
    doc = Hpricot(open(url))
    
    # Searching title...
    if doc.at('title')
      title = doc.at('title').inner_html
    else
      title = ""
    end
    
    # Searching meta description...
    if doc.at("meta[@name='description']")
      description = doc.at("meta[@name='description']")['content']
    else
      description = ""
    end
    
    # Searching meta keywords...
    if doc.at("meta[@name='keywords']")
      keywords = doc.at("meta[@name='keywords']")['content']
    else
      keywords = ""
    end
        
    # Searching links...
    links = []
    doc.search("//a").each do |link|
      links << link.attributes["href"] if (!link.attributes["href"].nil?)
    end
  
    # Returning all data...
    {'ok' => true, 'title' => title, 'description' => description, 'keywords' => keywords, 'links' => links}  

    rescue SocketError
      puts 'MetaInspector exception: The url provided does not exist or is temporarily unavailable (socket error)'
      {'ok' => false, 'title' => nil, 'description' => nil, 'keywords' => nil, 'links' => nil}  
  end
end
