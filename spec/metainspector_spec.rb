# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector do
  FakeWeb.register_uri(:get, "http://pagerankalert.com", :response => fixture_file("pagerankalert.com.response"))
  FakeWeb.register_uri(:get, "http://www.alazan.com", :response => fixture_file("alazan.com.response"))
  FakeWeb.register_uri(:get, "http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/", :response => fixture_file("theonion.com.response"))
  FakeWeb.register_uri(:get, "http://theonion-no-description.com", :response => fixture_file("theonion-no-description.com.response"))
  FakeWeb.register_uri(:get, "http://www.iteh.at", :response => fixture_file("iteh.at.response"))
  FakeWeb.register_uri(:get, "http://www.tea-tron.com/jbravo/blog/", :response => fixture_file("tea-tron.com.response"))
  FakeWeb.register_uri(:get, "http://www.guardian.co.uk/media/pda/2011/sep/15/techcrunch-arrington-startups", :response => fixture_file("guardian.co.uk.response"))
  FakeWeb.register_uri(:get, "http://protocol-relative.com", :response => fixture_file("protocol_relative.response"))
  FakeWeb.register_uri(:get, "https://protocol-relative.com", :response => fixture_file("protocol_relative.response"))
  FakeWeb.register_uri(:get, "http://example.com/nonhttp", :response => fixture_file("nonhttp.response"))

  describe 'Initialization' do
    it 'should accept an URL with a scheme' do
      @m = MetaInspector.new('http://pagerankalert.com')
      @m.url.should == 'http://pagerankalert.com'
    end

    it "should use http:// as a default scheme" do
      @m = MetaInspector.new('pagerankalert.com')
      @m.url.should == 'http://pagerankalert.com'
    end

    it "should store the scheme" do
      MetaInspector.new('http://pagerankalert.com').scheme.should   == 'http'
      MetaInspector.new('https://pagerankalert.com').scheme.should  == 'https'
    end
  end

  describe 'Doing a basic scrape' do
    EXPECTED_TITLE = 'PageRankAlert.com :: Track your PageRank changes'

    before(:each) do
      @m = MetaInspector.new('http://pagerankalert.com')
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
      @m.meta_og_image.should == "http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg"
    end

    it "should find all page images" do
      @m.absolute_images == ["http://pagerankalert.com/images/pagerank_alert.png?1309512337"]
      @m.images == ["/images/pagerank_alert.png?1309512337"]
    end

    it "should ignore malformed image tags" do
      # There is an image tag without a source. The scraper should not fatal.
      @m = MetaInspector.new("http://www.guardian.co.uk/media/pda/2011/sep/15/techcrunch-arrington-startups")
      @m.images.size.should == 11
    end

    it "should have a Nokogiri::HTML::Document as parsed_document" do
      @m.parsed_document.class.should == Nokogiri::HTML::Document
    end

    it "should have a String as document" do
      @m.document.class.should == String
    end

    it "should get rss feed" do
      @m = MetaInspector.new('http://www.iteh.at')
      @m.feed.should == 'http://www.iteh.at/de/rss/'
    end

    it "should get atom feed" do
      @m = MetaInspector.new('http://www.tea-tron.com/jbravo/blog/')
      @m.feed.should == 'http://www.tea-tron.com/jbravo/blog/feed/'
    end
  end

  describe 'Page with missing meta description' do
    it "should find secondary description" do
      @m = MetaInspector.new('http://theonion-no-description.com')
      @m.description == "SAN FRANCISCO&#8212;In a move expected to revolutionize the mobile device industry, Apple launched its fastest and most powerful iPhone to date Tuesday,"+
      " an innovative new model that can only be seen by the company's hippest and most dedicated customers. This is secondary text picked up because of a missing meta description."
    end
  end

  describe 'Links' do
    before(:each) do
      @m = MetaInspector.new('http://pagerankalert.com')
    end

    it "should get the links" do
      @m.links.should == [
                          "/",
                          "/es?language=es",
                          "/users/sign_up",
                          "/users/sign_in",
                          "mailto:pagerankalert@gmail.com",
                          "http://pagerankalert.posterous.com",
                          "http://twitter.com/pagerankalert",
                          "http://twitter.com/share"
                          ]
    end

    it "should convert links to absolute urls" do
      @m.absolute_links.should == [
                                    "http://pagerankalert.com/",
                                    "http://pagerankalert.com/es?language=es",
                                    "http://pagerankalert.com/users/sign_up",
                                    "http://pagerankalert.com/users/sign_in",
                                    "mailto:pagerankalert@gmail.com",
                                    "http://pagerankalert.posterous.com",
                                    "http://twitter.com/pagerankalert",
                                    "http://twitter.com/share"
                                  ]
    end
  end

  describe 'Non-HTTP links' do
    before(:each) do
      @m = MetaInspector.new('http://example.com/nonhttp')
    end

    it "should get the links" do
      @m.links.sort.should == [
                                "FTP://FTP.CDROM.COM",
                                "ftp://ftp.cdrom.com",
                                "javascript:alert('hey');",
                                "mailto:user@example.com",
                                "skype:joeuser?call",
                                "telnet://telnet.cdrom.com"
                              ]
    end

    it "should return the same links as absolute links do" do
      @m.absolute_links.should == @m.links
    end
  end

  describe 'Protocol-relative URLs' do
    before(:each) do
      @m_http   = MetaInspector.new('http://protocol-relative.com')
      @m_https  = MetaInspector.new('https://protocol-relative.com')
    end

    it "should convert protocol-relative links to http" do
      @m_http.absolute_links.should include('http://protocol-relative.com/contact')
      @m_http.absolute_links.should include('http://yahoo.com')
    end

    it "should convert protocol-relative links to https" do
      @m_https.absolute_links.should include('https://protocol-relative.com/contact')
      @m_https.absolute_links.should include('https://yahoo.com')
    end
  end

  describe 'Getting meta tags by ghost methods' do
    before(:each) do
      @m = MetaInspector.new('http://pagerankalert.com')
    end

    it "should get the robots meta tag" do
      @m.meta_robots.should == 'all,follow'
    end

    it "should get the robots meta tag" do
      @m.meta_RoBoTs.should == 'all,follow'
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

    it "should get the Csrf_pAram meta tag" do
      @m.meta_Csrf_pAram.should == "authenticity_token"
    end

    it "should get the generator meta tag" do
      pending "mocks"
      @m.meta_generator.should == 'WordPress 2.8.4'
    end

    it "should return nil for nonfound meta_tags" do
      @m.meta_lollypop.should == nil
    end

    it "should find a meta_og_title" do
      @m = MetaInspector.new('http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')
      @m.meta_og_title.should == "Apple Claims New iPhone Only Visible To Most Loyal Of Customers"
    end

    it "should not find a meta_og_something" do
      @m = MetaInspector.new('http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')
      @m.meta_og_something.should == nil
    end

  end

  describe 'Charset detection' do
    it "should detect windows-1252 charset" do
      @m = MetaInspector.new('http://www.alazan.com')
      @m.charset.should == "windows-1252"
    end

    it "should detect utf-8 charset" do
      @m = MetaInspector.new('http://pagerankalert.com')
      @m.charset.should == "utf-8"
    end
  end

  describe 'to_hash' do
    it "should return a hash with all the values set" do
      @m = MetaInspector.new('http://pagerankalert.com')
      @m.to_hash.should == {"title"=>"PageRankAlert.com :: Track your PageRank changes", "url"=>"http://pagerankalert.com", "meta"=>{"name"=>{"robots"=>"all,follow", "csrf_param"=>"authenticity_token", "description"=>"Track your PageRank(TM) changes and receive alerts by email", "keywords"=>"pagerank, seo, optimization, google", "csrf_token"=>"iW1/w+R8zrtDkhOlivkLZ793BN04Kr3X/pS+ixObHsE="}, "property"=>{}}, "links"=>["/", "/es?language=es", "/users/sign_up", "/users/sign_in", "mailto:pagerankalert@gmail.com", "http://pagerankalert.posterous.com", "http://twitter.com/pagerankalert", "http://twitter.com/share"], "charset"=>"utf-8", "feed"=>"http://feeds.feedburner.com/PageRankAlert", "absolute_links"=>["http://pagerankalert.com/", "http://pagerankalert.com/es?language=es", "http://pagerankalert.com/users/sign_up", "http://pagerankalert.com/users/sign_in", "mailto:pagerankalert@gmail.com", "http://pagerankalert.posterous.com", "http://twitter.com/pagerankalert", "http://twitter.com/share"]}
    end
  end
end