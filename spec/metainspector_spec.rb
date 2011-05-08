# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector do

  context 'Doing a basic scrape' do
    EXPECTED_TITLE = 'PageRankAlert.com :: Track your PageRank changes'
    
    before(:each) do
      @m = MetaInspector.new('http://pagerankalert.com')
    end
    
    it "should not fatal if you forget to use a scheme" do
      @m = MetaInspector.new('pagerankalert.com')
      @m.title.should == EXPECTED_TITLE
    end

    it "should get the title" do
      @m.title.should == EXPECTED_TITLE
    end
    
    it "should not find an image" do 
      @m.image.should == nil
    end
          
    it "should find an image" do 
      @m = MetaInspector.new('http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')
      @m.image.should == "http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg"
    end

    it "should get the links" do
      @m.links.size.should == 8
    end

    it "should have a Nokogiri::HTML::Document as parsed_document" do
      @m.parsed_document.class.should == Nokogiri::HTML::Document
    end

    it "should have a String as document" do
      @m.document.class.should == String
    end
  end

  context 'Getting meta tags by ghost methods' do
    before(:each) do
      @m = MetaInspector.new('http://pagerankalert.com')
    end

    it "should get the robots meta tag" do
      @m.meta_robots.should == 'all,follow'
    end

    it "should get the description meta tag" do
      @m.meta_description.should == 'Track your PageRank(TM) changes and receive alerts by email'
    end

    it "should get the keywords meta tag" do
      @m.meta_keywords.should == "pagerank, seo, optimization, google"
    end

    it "should get the content-language meta tag" do
      pending "mocks"
      @m.meta_content_language.should == "en"
    end

    it "should get the Content-Type meta tag" do
      pending "mocks"
      @m.meta_Content_Type.should == "text/html; charset=utf-8"
    end

    it "should get the generator meta tag" do
      pending "mocks"
      @m.meta_generator.should == 'WordPress 2.8.4'
    end

    it "should return nil for nonfound meta_tags" do
      @m.meta_lollypop.should == nil
    end
  end

  context 'Charset detection' do
    it "should detect windows-1252 charset" do
      @m = MetaInspector.new('http://www.alazan.com')
      @m.charset.should == "windows-1252"
    end

    it "should detect utf-8 charset" do
      @m = MetaInspector.new('http://www.pagerankalert.com')
      @m.charset.should == "utf-8"
    end
  end
end