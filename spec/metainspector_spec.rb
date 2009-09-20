require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector do
  context 'Doing a basic scrape' do
    before(:each) do
      @m = MetaInspector.new('http://pagerankalert.com')
    end
    
    it "should get the title" do
      @m.title.should == 'PageRankAlert.com :: Track your pagerank changes'
    end
    
    it "should get the description" do
      @m.description.should == 'Track your PageRank(TM) changes and receive alert by email'
    end
    
    it "should get the keywords" do
      @m.keywords.should == "pagerank, seo, optimization, google"
    end
    
    it "should get the links" do
      @m.links.size.should == 7
    end
    
    it "should have a Nokogiri::HTML::Document as parsed_document" do
      @m.parsed_document.class.should == Nokogiri::HTML::Document
    end
    
    it "should have a String as document" do
      @m.document.class.should == String
    end
  end
end

