# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector do
  FakeWeb.register_uri(:get, "http://pagerankalert.com", :response => fixture_file("pagerankalert.com.response"))
  FakeWeb.register_uri(:get, "pagerankalert.com", :response => fixture_file("pagerankalert.com.response"))
  FakeWeb.register_uri(:get, "http://www.alazan.com", :response => fixture_file("alazan.com.response"))
  FakeWeb.register_uri(:get, "http://alazan.com/websolution.asp", :response => fixture_file("alazan_websolution.response"))
  FakeWeb.register_uri(:get, "http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/", :response => fixture_file("theonion.com.response"))
  FakeWeb.register_uri(:get, "http://theonion-no-description.com", :response => fixture_file("theonion-no-description.com.response"))
  FakeWeb.register_uri(:get, "http://www.iteh.at", :response => fixture_file("iteh.at.response"))
  FakeWeb.register_uri(:get, "http://www.tea-tron.com/jbravo/blog/", :response => fixture_file("tea-tron.com.response"))
  FakeWeb.register_uri(:get, "http://www.guardian.co.uk/media/pda/2011/sep/15/techcrunch-arrington-startups", :response => fixture_file("guardian.co.uk.response"))
  FakeWeb.register_uri(:get, "http://protocol-relative.com", :response => fixture_file("protocol_relative.response"))
  FakeWeb.register_uri(:get, "https://protocol-relative.com", :response => fixture_file("protocol_relative.response"))
  FakeWeb.register_uri(:get, "http://example.com/nonhttp", :response => fixture_file("nonhttp.response"))
  FakeWeb.register_uri(:get, "http://www.youtube.com/watch?v=iaGSSrp49uc", :response => fixture_file("youtube.response"))
  FakeWeb.register_uri(:get, "http://markupvalidator.com/faqs", :response => fixture_file("markupvalidator_faqs.response"))
  FakeWeb.register_uri(:get, "https://twitter.com/markupvalidator", :response => fixture_file("twitter_markupvalidator.response"))
  FakeWeb.register_uri(:get, "https://example.com/empty", :response => fixture_file("empty_page.response"))
  FakeWeb.register_uri(:get, "http://international.com", :response => fixture_file("international.response"))
  FakeWeb.register_uri(:get, "http://charset000.com", :response => fixture_file("charset_000.response"))
  FakeWeb.register_uri(:get, "http://charset001.com", :response => fixture_file("charset_001.response"))
  FakeWeb.register_uri(:get, "http://charset002.com", :response => fixture_file("charset_002.response"))
  FakeWeb.register_uri(:get, "http://www.inkthemes.com/", :response => fixture_file("wordpress_site.response"))

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
      MetaInspector.new('pagerankalert.com').scheme.should          == 'http'
    end

    it "should store the host" do
      MetaInspector.new('http://pagerankalert.com').host.should   == 'pagerankalert.com'
      MetaInspector.new('https://pagerankalert.com').host.should  == 'pagerankalert.com'
      MetaInspector.new('pagerankalert.com').host.should          == 'pagerankalert.com'
    end

    it "should store the root url" do
      MetaInspector.new('http://pagerankalert.com').root_url.should   == 'http://pagerankalert.com/'
      MetaInspector.new('https://pagerankalert.com').root_url.should  == 'https://pagerankalert.com/'
      MetaInspector.new('pagerankalert.com').root_url.should          == 'http://pagerankalert.com/'
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

    describe "get image" do
      it "should find the og image" do
        @m = MetaInspector.new('http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')
        @m.image.should == "http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg"
        @m.meta_og_image.should == "http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg"
      end

      it "should find image on youtube" do
        MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc').image.should == "http://i2.ytimg.com/vi/iaGSSrp49uc/mqdefault.jpg"
      end
    end

    describe "get images" do
      it "should find all page images" do
        @m.images == ["http://pagerankalert.com/images/pagerank_alert.png?1309512337"]
      end

      it "should find images on twitter" do
        m = MetaInspector.new('https://twitter.com/markupvalidator')
        m.images.length.should == 6
        m.images.join("; ").should == "https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_reasonably_small.png; https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_normal.png; https://twimg0-a.akamaihd.net/profile_images/2293774732/v0pgo4xpdd9rou2xq5h0_normal.png; https://twimg0-a.akamaihd.net/profile_images/1538528659/jaime_nov_08_normal.jpg; https://si0.twimg.com/sticky/default_profile_images/default_profile_6_mini.png; https://twimg0-a.akamaihd.net/a/1342841381/images/bigger_spinner.gif"
      end
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

    describe "get description" do
      it "should find description on youtube" do
        MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc').description.should == ""
      end
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
      @m.internal_links.should == [ "http://pagerankalert.com/",
                           "http://pagerankalert.com/es?language=es",
                           "http://pagerankalert.com/users/sign_up",
                           "http://pagerankalert.com/users/sign_in" ]
    end

    it "should get correct absolute links for external pages" do
      @m.external_links.should == [ "mailto:pagerankalert@gmail.com",
                           "http://pagerankalert.posterous.com",
                           "http://twitter.com/pagerankalert",
                           "http://twitter.com/share" ]
    end

    it "should get correct absolute links, correcting relative links from URL not ending with slash" do
      m = MetaInspector.new('http://alazan.com/websolution.asp')
      m.links.should == [ "http://alazan.com/index.asp",
                          "http://alazan.com/faqs.asp" ]
    end

    it "should get correct absolute links, encoding the URLs as needed but respecting # and ?" do
      m = MetaInspector.new('http://international.com')
      m.links.should == [ "http://international.com/espa%C3%B1a.asp",
                          "http://international.com/roman%C3%A9e",
                          "http://international.com/faqs#cami%C3%B3n",
                          "http://international.com/search?q=cami%C3%B3n",
                          "http://international.com/search?q=espa%C3%B1a#top"]
    end

    it "should return empty array if no links found" do
      m = MetaInspector.new('http://example.com/empty')
      m.links.should == []
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

    it "should return nil for nonfound meta_tags" do
      @m.meta_lollypop.should == nil
    end

    it "should get the generator meta tag" do
      @m = MetaInspector.new('http://www.inkthemes.com/')
      @m.meta_generator.should == 'WordPress 3.4.2'
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
    it "should get the charset from <meta charset />" do
      @m = MetaInspector.new('http://charset001.com')
      @m.charset.should == "utf-8"
    end

    it "should get the charset from meta content type" do
      @m = MetaInspector.new('http://charset002.com')
      @m.charset.should == "windows-1252"
    end

    it "should get nil if no declared charset is found" do
      @m = MetaInspector.new('http://charset000.com')
      @m.charset.should == nil
    end
  end

  describe 'to_hash' do
    it "should return a hash with all the values set" do
      @m = MetaInspector.new('http://pagerankalert.com')
      @m.to_hash.should == {"title"=>"PageRankAlert.com :: Track your PageRank changes", "url"=>"http://pagerankalert.com", "meta"=>{"name"=>{"robots"=>"all,follow", "csrf_param"=>"authenticity_token", "description"=>"Track your PageRank(TM) changes and receive alerts by email", "keywords"=>"pagerank, seo, optimization, google", "csrf_token"=>"iW1/w+R8zrtDkhOlivkLZ793BN04Kr3X/pS+ixObHsE="}, "property"=>{}}, "images"=>["http://pagerankalert.com/images/pagerank_alert.png?1305794559"], "charset"=>"utf-8", "feed"=>"http://feeds.feedburner.com/PageRankAlert", "links"=>["http://pagerankalert.com/", "http://pagerankalert.com/es?language=es", "http://pagerankalert.com/users/sign_up", "http://pagerankalert.com/users/sign_in", "mailto:pagerankalert@gmail.com", "http://pagerankalert.posterous.com", "http://twitter.com/pagerankalert", "http://twitter.com/share"], "internal_links"=>["http://pagerankalert.com/", "http://pagerankalert.com/es?language=es", "http://pagerankalert.com/users/sign_up", "http://pagerankalert.com/users/sign_in"], "external_links" => ["mailto:pagerankalert@gmail.com", "http://pagerankalert.posterous.com", "http://twitter.com/pagerankalert", "http://twitter.com/share"]}
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
      impatient = MetaInspector.new('http://markupvalidator.com', 0.0000000000001)

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
        good  = MetaInspector.new('http://pagerankalert.com')
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

end