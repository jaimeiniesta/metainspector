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
end
