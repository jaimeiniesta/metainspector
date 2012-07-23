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
  FakeWeb.register_uri(:get, "http://www.youtube.com/watch?v=iaGSSrp49uc", :response => fixture_file("youtube.response"))
  FakeWeb.register_uri(:get, "http://w3clove.com/faqs", :response => fixture_file("w3clove_faqs.response"))

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

    it "should store the host" do
      MetaInspector.new('http://pagerankalert.com').host.should   == 'pagerankalert.com'
      MetaInspector.new('https://pagerankalert.com').host.should  == 'pagerankalert.com'
    end

    it "should store the root url" do
      MetaInspector.new('http://pagerankalert.com').root_url.should   == 'http://pagerankalert.com/'
      MetaInspector.new('https://pagerankalert.com').root_url.should  == 'https://pagerankalert.com/'
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
      @m.images == ["http://pagerankalert.com/images/pagerank_alert.png?1309512337"]
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
      @m.links.should == [ "http://pagerankalert.com/",
                           "http://pagerankalert.com/es?language=es",
                           "http://pagerankalert.com/users/sign_up",
                           "http://pagerankalert.com/users/sign_in",
                           "mailto:pagerankalert@gmail.com",
                           "http://pagerankalert.posterous.com",
                           "http://twitter.com/pagerankalert",
                           "http://twitter.com/share" ]
    end

    it "should get correct absolute links for internal pages" do
      m = MetaInspector.new('http://w3clove.com/faqs')
      m.links.should == [ "http://w3clove.com/faqs/#",
                          "http://w3clove.com/",
                          "http://w3clove.com/faqs",
                          "http://w3clove.com/plans-and-pricing",
                          "http://w3clove.com/contact",
                          "http://w3clove.com/charts/errors",
                          "http://w3clove.com/credits",
                          "http://w3clove.com/signin",
                          "http://validator.w3.org",
                          "http://www.sitemaps.org/",
                          "http://jaimeiniesta.com/",
                          "http://mendicantuniversity.org/",
                          "http://jaimeiniesta.posterous.com/rbmu-a-better-way-to-learn-ruby",
                          "http://majesticseacreature.com/",
                          "http://school.mendicantuniversity.org/alumni/2011",
                          "https://github.com/jaimeiniesta/w3clove",
                          "http://w3clove.com",
                          "http://w3clove.com/api_v1_reference",
                          "https://twitter.com/w3clove",
                          "http://twitter.com/share",
                          "http://w3clove.com/terms_of_service",
                          "http://twitter.com/W3CLove",
                          "http://us4.campaign-archive1.com/home/?u=6af3ab69c286561d0f0f25671&id=04a0dab609" ]
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
  end

  describe 'Protocol-relative URLs' do
    before(:each) do
      @m_http   = MetaInspector.new('http://protocol-relative.com')
      @m_https  = MetaInspector.new('https://protocol-relative.com')
    end

    it "should convert protocol-relative links to http" do
      @m_http.links.should include('http://protocol-relative.com/contact')
      @m_http.links.should include('http://yahoo.com')
    end

    it "should convert protocol-relative links to https" do
      @m_https.links.should include('https://protocol-relative.com/contact')
      @m_https.links.should include('https://yahoo.com')
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
      @m.to_hash.should == {"title"=>"PageRankAlert.com :: Track your PageRank changes", "url"=>"http://pagerankalert.com", "meta"=>{"name"=>{"robots"=>"all,follow", "csrf_param"=>"authenticity_token", "description"=>"Track your PageRank(TM) changes and receive alerts by email", "keywords"=>"pagerank, seo, optimization, google", "csrf_token"=>"iW1/w+R8zrtDkhOlivkLZ793BN04Kr3X/pS+ixObHsE="}, "property"=>{}}, "images"=>["http://pagerankalert.com/images/pagerank_alert.png?1305794559"], "charset"=>"utf-8", "feed"=>"http://feeds.feedburner.com/PageRankAlert", "links"=>["http://pagerankalert.com/", "http://pagerankalert.com/es?language=es", "http://pagerankalert.com/users/sign_up", "http://pagerankalert.com/users/sign_in", "mailto:pagerankalert@gmail.com", "http://pagerankalert.posterous.com", "http://twitter.com/pagerankalert", "http://twitter.com/share"]}
    end
  end

  describe 'exception handling' do
    before(:each) do
      FakeWeb.allow_net_connect = true
    end

    after(:each) do
      FakeWeb.allow_net_connect = false
    end

    it "should handle timeouts" do
      impatient = MetaInspector.new('http://w3clove.com', 0.0000000000001)

      expect {
        title = impatient.title
      }.to change { impatient.errors.size }

      impatient.errors.first.should == "Timeout!!!"
    end

    it "should handle socket errors" do
      nowhere = MetaInspector.new('http://caca232dsdsaer3sdsd-asd343.org')

      expect {
        title = nowhere.title
      }.to change { nowhere.errors.size }

      nowhere.errors.first.should == "Socket error: The url provided does not exist or is temporarily unavailable"
    end

    describe "parsed?" do
      it "should return true if we have a parsed document" do
        good  = MetaInspector.new('http://w3clove.com')
        title = good.title

        good.parsed?.should == true
      end

      it "should return false if we don't have a parsed document" do
        bad  = MetaInspector.new('http://fdsfdferewrewewewdesdf.com', 0.00000000000001)
        title = bad.title

        bad.parsed?.should == false
      end
    end
  end

  describe "regression tests" do
    describe "get image" do
      it "should find image on youtube" do
        MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc').image.should == "http://i2.ytimg.com/vi/iaGSSrp49uc/mqdefault.jpg"
      end
    end

    describe "get description" do
      it "should find description on youtube" do
        MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc').description.should == ""
      end
    end
  end
end