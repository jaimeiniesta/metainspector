require 'test/unit'
require '../lib/metainspector.rb'

class TestMetaInspector < Test::Unit::TestCase
  # TODO: mock tests
  # TODO: validate URL format, only http and https allowed
  # TODO: check timeouts
  
  # Test scraping an URL, marking it as scraped and setting meta data values
  def test_scrape
    m = MetaInspector.new('http://pagerankalert.com')
    assert_equal m.title, 'PageRankAlert.com :: Track your pagerank changes'
    assert_equal m.description, 'Track your PageRank(TM) changes and receive alert by email'
    assert_equal m.keywords, 'pagerank, seo, optimization, google'
    assert_equal m.links.size, 31
    assert_equal m.links[30], 'http://www.nuvio.cz/'
    assert_equal m.document.class, Nokogiri::HTML::Document
  end
  
  # Test changing the address resets the state of the instance so it causes a new scraping
  def test_address_setter
    m = MetaInspector.new('http://pagerankalert.com')
    assert_equal m.address, 'http://pagerankalert.com'
    title_1 = m.title
    description_1 = m.description
    keywords_1 = m.keywords
    links_1 = m.links
    document_1 = m.document 
    
    m.address = 'http://jaimeiniesta.com'
    assert_equal m.address, 'http://jaimeiniesta.com'
    title_2 = m.title
    description_2 = m.description
    keywords_2 = m.keywords
    links_2 = m.links
    document_2 = m.document
    
    assert_not_equal title_1, title_2
    assert_not_equal description_1, description_2
    assert_not_equal keywords_1, keywords_2
    assert_not_equal links_1, links_2
    assert_not_equal document_1, document_2
  end
end
