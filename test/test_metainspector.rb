require 'test/unit'
require '../lib/metainspector.rb'

class TestMetaInspector < Test::Unit::TestCase
  # TODO: mock tests
  
  # Test we can initialize a new instance, setting its address, and initial state
  # is not scraped and every meta data value set to nil
  # TODO: validate URL format, only http and https allowed
  def test_initialize
    m = MetaInspector.new('http://pagerankalert.com')
    assert_equal m.address, 'http://pagerankalert.com'
    assert_equal m.scraped?, false
    assert_nil m.title
    assert_nil m.description
    assert_nil m.keywords
    assert_equal m.links.size, 0
    assert_nil m.full_doc
    assert_nil m.scraped_doc
  end
  
  # Test scraping an URL, marking it as scraped and setting meta data values
  # TODO: check timeouts
  def test_scrape!
    m = MetaInspector.new('http://pagerankalert.com')
    assert m.scrape!
    assert m.scraped?
    assert_equal m.title, 'PageRankAlert.com :: Track your pagerank changes'
    assert_equal m.description, 'Track your PageRank(TM) changes and receive alert by email'
    assert_equal m.keywords, 'pagerank, seo, optimization, google'
    assert_equal m.links.size, 31
    assert_equal m.links[30], 'http://www.nuvio.cz/'
    assert_equal m.full_doc.class, Tempfile
    assert_equal m.scraped_doc.class, Nokogiri::HTML::Document
  end
  
  # Test changing the address resets the state of the instance
  def test_address_setter
    m = MetaInspector.new('http://pagerankalert.com')
    assert_equal m.address, 'http://pagerankalert.com'
    m.scrape!
    assert m.scraped?
    assert_not_nil m.title
    assert_not_nil m.description
    assert_not_nil m.keywords
    assert_not_nil m.links
    assert_not_nil m.full_doc
    assert_not_nil m.scraped_doc
    
    m.address = 'http://jaimeiniesta.com'
    assert_equal m.address, 'http://jaimeiniesta.com'
    assert !m.scraped?
    assert_nil m.title
    assert_nil m.description
    assert_nil m.keywords
    assert_equal m.links.size, 0
    assert_nil m.full_doc
    assert_nil m.scraped_doc    
  end
end
