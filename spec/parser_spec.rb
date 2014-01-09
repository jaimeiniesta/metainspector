# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector::Parser do
  describe 'Doing a basic scrape' do

    before(:each) do
      @m = MetaInspector::Parser.new(doc 'http://pagerankalert.com')
    end

    it "should get the title" do
      @m.title.should == 'PageRankAlert.com :: Track your PageRank changes & receive alerts'
    end

    it "should not find an image" do
      @m.image.should == nil
    end

    describe "get image" do
      it "should find the og image" do
        @m = MetaInspector::Parser.new(doc 'http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')
        @m.image.should == "http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg"
        @m.meta_og_image.should == "http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg"
      end

      it "should find image on youtube" do
        MetaInspector::Parser.new(doc 'http://www.youtube.com/watch?v=iaGSSrp49uc').image.should == "http://i2.ytimg.com/vi/iaGSSrp49uc/mqdefault.jpg"
      end
    end

    describe "get images" do
      it "should find all page images" do
        @m.images.should == ["http://pagerankalert.com/images/pagerank_alert.png?1305794559"]
      end

      it "should find images on twitter" do
        m = MetaInspector::Parser.new(doc 'https://twitter.com/markupvalidator')
        m.images.length.should == 6
        m.images.join("; ").should == "https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_reasonably_small.png; https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_normal.png; https://twimg0-a.akamaihd.net/profile_images/2293774732/v0pgo4xpdd9rou2xq5h0_normal.png; https://twimg0-a.akamaihd.net/profile_images/1538528659/jaime_nov_08_normal.jpg; https://si0.twimg.com/sticky/default_profile_images/default_profile_6_mini.png; https://twimg0-a.akamaihd.net/a/1342841381/images/bigger_spinner.gif"
      end
    end

    it "should ignore malformed image tags" do
      # There is an image tag without a source. The scraper should not fatal.
      @m = MetaInspector::Parser.new(doc "http://www.guardian.co.uk/media/pda/2011/sep/15/techcrunch-arrington-startups")
      @m.images.size.should == 11
    end

    it "should have a Nokogiri::HTML::Document as parsed" do
      @m.parsed.class.should == Nokogiri::HTML::Document
    end

    it "should return the document as a string" do
      @m.to_s.class.should == String
    end

    describe "Feed" do
      it "should get rss feed" do
        @m = MetaInspector::Parser.new(doc 'http://www.iteh.at')
        @m.feed.should == 'http://www.iteh.at/de/rss/'
      end

      it "should get atom feed" do
        @m = MetaInspector::Parser.new(doc 'http://www.tea-tron.com/jbravo/blog/')
        @m.feed.should == 'http://www.tea-tron.com/jbravo/blog/feed/'
      end

      it "should return nil if no feed found" do
        @m = MetaInspector::Parser.new(doc 'http://www.alazan.com')
        @m.feed.should == nil
      end
    end

    describe "get description" do
      it "should find description on youtube" do
        MetaInspector::Parser.new(doc 'http://www.youtube.com/watch?v=iaGSSrp49uc').description.should == ""
      end
    end
  end

  describe 'Page with missing meta description' do
    it "should find a secondary description" do
      @m = MetaInspector::Parser.new(doc 'http://theonion-no-description.com')
      @m.description.should == "SAN FRANCISCO—In a move expected to revolutionize the mobile device industry, Apple launched its fastest and most powerful iPhone to date Tuesday, an innovative new model that can only be seen by the company's hippest and most dedicated customers. This is secondary text picked up because of a missing meta description."
    end
  end

  describe 'Links' do
    before(:each) do
      @m = MetaInspector::Parser.new(doc 'http://pagerankalert.com')
    end

    it "should get the links" do
      @m.links.should == [ "http://pagerankalert.com/",
                           "http://pagerankalert.com/es?language=es",
                           "http://pagerankalert.com/users/sign_up",
                           "http://pagerankalert.com/users/sign_in",
                           "mailto:pagerankalert@gmail.com",
                           "http://pagerankalert.posterous.com/",
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
                           "http://pagerankalert.posterous.com/",
                           "http://twitter.com/pagerankalert",
                           "http://twitter.com/share" ]
    end

    it "should get correct absolute links, correcting relative links from URL not ending with slash" do
      m = MetaInspector::Parser.new(doc 'http://alazan.com/websolution.asp')
      m.links.should == [ "http://alazan.com/index.asp",
                          "http://alazan.com/faqs.asp" ]
    end

    it "should return empty array if no links found" do
      m = MetaInspector::Parser.new(doc 'http://example.com/empty')
      m.links.should == []
    end

    describe "links with international characters" do
      it "should get correct absolute links, encoding the URLs as needed" do
        m = MetaInspector::Parser.new(doc 'http://international.com')
        m.links.should == [ "http://international.com/espa%C3%B1a.asp",
                            "http://international.com/roman%C3%A9e",
                            "http://international.com/faqs#cami%C3%B3n",
                            "http://international.com/search?q=cami%C3%B3n",
                            "http://international.com/search?q=espa%C3%B1a#top",
                            "http://international.com/index.php?q=espa%C3%B1a&url=aHR0zZQ==&cntnt01pageid=21",
                            "http://example.com/espa%C3%B1a.asp",
                            "http://example.com/roman%C3%A9e",
                            "http://example.com/faqs#cami%C3%B3n",
                            "http://example.com/search?q=cami%C3%B3n",
                            "http://example.com/search?q=espa%C3%B1a#top"]
      end

      describe "internal links" do
        it "should get correct internal links, encoding the URLs as needed but respecting # and ?" do
          m = MetaInspector::Parser.new(doc 'http://international.com')
          m.internal_links.should == [ "http://international.com/espa%C3%B1a.asp",
                                       "http://international.com/roman%C3%A9e",
                                       "http://international.com/faqs#cami%C3%B3n",
                                       "http://international.com/search?q=cami%C3%B3n",
                                       "http://international.com/search?q=espa%C3%B1a#top",
                                       "http://international.com/index.php?q=espa%C3%B1a&url=aHR0zZQ==&cntnt01pageid=21"]
        end

        it "should not crash when processing malformed hrefs" do
          m = MetaInspector::Parser.new(doc 'http://example.com/malformed_href')
          expect {
            m.internal_links.should == [ "http://example.com/faqs" ]
            m.should be_ok
          }.to_not raise_error
        end
      end

      describe "external links" do
        it "should get correct external links, encoding the URLs as needed but respecting # and ?" do
          m = MetaInspector::Parser.new(doc 'http://international.com')
          m.external_links.should == [ "http://example.com/espa%C3%B1a.asp",
                                       "http://example.com/roman%C3%A9e",
                                       "http://example.com/faqs#cami%C3%B3n",
                                       "http://example.com/search?q=cami%C3%B3n",
                                       "http://example.com/search?q=espa%C3%B1a#top"]
        end

        it "should not crash when processing malformed hrefs" do
          m = MetaInspector::Parser.new(doc 'http://example.com/malformed_href')
          expect {
            m.external_links.should == ["skype:joeuser?call", "telnet://telnet.cdrom.com",
                                        "javascript:alert('ok');", "javascript://", "mailto:email(at)example.com"]
            m.should be_ok
          }.to_not raise_error
        end
      end
    end

    it "should not crash with links that have weird href values" do
      m = MetaInspector::Parser.new(doc 'http://example.com/invalid_href')
      m.links.should == ["%3Cp%3Eftp://ftp.cdrom.com", "skype:joeuser?call", "telnet://telnet.cdrom.com"]
    end
  end

  describe 'Relative links' do
    describe 'From a root URL' do
      before(:each) do
        @m = MetaInspector::Parser.new(doc 'http://relative.com/')
      end

      it 'should get the relative links' do
        @m.internal_links.should == ['http://relative.com/about', 'http://relative.com/sitemap']
      end
    end

    describe 'From a document' do
      before(:each) do
        @m = MetaInspector::Parser.new(doc 'http://relative.com/company')
      end

      it 'should get the relative links' do
        @m.internal_links.should == ['http://relative.com/about', 'http://relative.com/sitemap']
      end
    end

    describe 'From a directory' do
      before(:each) do
        @m = MetaInspector::Parser.new(doc 'http://relative.com/company/')
      end

      it 'should get the relative links' do
        @m.internal_links.should == ['http://relative.com/company/about', 'http://relative.com/sitemap']
      end
    end
  end

  describe 'Relative links with base' do
    it 'should get the relative links from a document' do
      m = MetaInspector::Parser.new(doc 'http://relativewithbase.com/company/page2')
      m.internal_links.should == ['http://relativewithbase.com/about', 'http://relativewithbase.com/sitemap']
    end

    it 'should get the relative links from a directory' do
      m = MetaInspector::Parser.new(doc 'http://relativewithbase.com/company/page2/')
      m.internal_links.should == ['http://relativewithbase.com/about', 'http://relativewithbase.com/sitemap']
    end
  end

  describe 'Non-HTTP links' do
    before(:each) do
      @m = MetaInspector::Parser.new(doc 'http://example.com/nonhttp')
    end

    it "should get the links" do
      @m.links.sort.should == [
                                "ftp://ftp.cdrom.com/",
                                "javascript:alert('hey');",
                                "mailto:user@example.com",
                                "skype:joeuser?call",
                                "telnet://telnet.cdrom.com"
                              ]
    end
  end

  describe 'Protocol-relative URLs' do
    before(:each) do
      @m_http   = MetaInspector::Parser.new(doc 'http://protocol-relative.com')
      @m_https  = MetaInspector::Parser.new(doc 'https://protocol-relative.com')
    end

    it "should convert protocol-relative links to http" do
      @m_http.links.should include('http://protocol-relative.com/contact')
      @m_http.links.should include('http://yahoo.com/')
    end

    it "should convert protocol-relative links to https" do
      @m_https.links.should include('https://protocol-relative.com/contact')
      @m_https.links.should include('https://yahoo.com/')
    end
  end

  describe 'respond_to? for meta tags ghost methods' do
    before(:each) do
      @m = MetaInspector.new('http://pagerankalert.com')
    end

    it "should return true for meta tags as string" do
      @m.respond_to?("meta_robots").should be_true
    end

    it "should return true for meta tags as symbols" do
      @m.respond_to?(:meta_robots).should be_true
    end

    it "should return true for meta_twitter_site as string" do
      @m = MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc')
      @m.respond_to?("meta_twitter_site").should be_true
    end

    it "should return true for meta_twitter_site as symbol" do
      @m = MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc')
      @m.respond_to?(:meta_twitter_player_width).should be_true
    end
  end

  describe 'respond_to? for not implemented methods' do

    before(:each) do
      @m = MetaInspector.new('http://pagerankalert.com')
    end

    it "should return false when method name passed as string" do
      @m.respond_to?("method_not_implemented").should be_false
    end

    it "should return false when method name passed as symbols" do
      @m = MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc')
      @m.respond_to?(:method_not_implemented).should be_false
    end
  end

  describe 'Getting meta tags by ghost methods' do
    before(:each) do
      @m = MetaInspector::Parser.new(doc 'http://pagerankalert.com')
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
      @m = MetaInspector::Parser.new(doc 'http://www.inkthemes.com/')
      @m.meta_generator.should == 'WordPress 3.4.2'
    end

    it "should find a meta_twitter_site" do
      @m = MetaInspector::Parser.new(doc 'http://www.youtube.com/watch?v=iaGSSrp49uc')
      @m.meta_twitter_site.should == "@youtube"
    end

    it "should find a meta_twitter_player_width" do
      @m = MetaInspector::Parser.new(doc 'http://www.youtube.com/watch?v=iaGSSrp49uc')
      @m.meta_twitter_player_width.should == "1920"
    end

    it "should not find a meta_twitter_dummy" do
      @m = MetaInspector::Parser.new(doc 'http://www.youtube.com/watch?v=iaGSSrp49uc')
      @m.meta_twitter_dummy.should == nil
    end

    describe "opengraph meta tags" do
      before(:each) do
        @m = MetaInspector::Parser.new(doc 'http://example.com/opengraph')
      end

      it "should find a meta og:title" do
        @m.meta_og_title.should == "An OG title"
      end

      it "should find a meta og:type" do
        @m.meta_og_type.should == "website"
      end

      it "should find a meta og:url" do
        @m.meta_og_url.should == "http://example.com/opengraph"
      end

      it "should find a meta og:description" do
        @m.meta_og_description.should == "Sean Connery found fame and fortune"
      end

      it "should find a meta og:determiner" do
        @m.meta_og_determiner.should == "the"
      end

      it "should find a meta og:locale" do
        @m.meta_og_locale.should == "en_GB"
      end

      it "should find a meta og:locale:alternate" do
        @m.meta_og_locale_alternate.should == "fr_FR"
      end

      it "should find a meta og:site_name" do
        @m.meta_og_site_name.should == "IMDb"
      end

      it "should find a meta og:image" do
        @m.meta_og_image.should == "http://example.com/ogp.jpg"
      end

      it "should find a meta og:image:secure_url" do
        @m.meta_og_image_secure_url.should == "https://secure.example.com/ogp.jpg"
      end

      it "should find a meta og:image:type" do
        @m.meta_og_image_type.should == "image/jpeg"
      end

      it "should find a meta og:image:width" do
        @m.meta_og_image_width.should == "400"
      end

      it "should find a meta og:image:height" do
        @m.meta_og_image_height.should == "300"
      end

      it "should find a meta og:video" do
        @m.meta_og_video.should == "http://example.com/movie.swf"
      end

      it "should find a meta og:video:secure_url" do
        @m.meta_og_video_secure_url.should == "https://secure.example.com/movie.swf"
      end

      it "should find a meta og:video:type" do
        @m.meta_og_video_type.should == "application/x-shockwave-flash"
      end

      it "should find a meta og:video:width" do
        @m.meta_og_video_width.should == "400"
      end

      it "should find a meta og:video:height" do
        @m.meta_og_video_height.should == "300"
      end

      it "should find a meta og:audio" do
        @m.meta_og_audio.should == "http://example.com/sound.mp3"
      end

      it "should find a meta og:video:secure_url" do
        @m.meta_og_audio_secure_url.should == "https://secure.example.com/sound.mp3"
      end

      it "should find a meta og:audio:type" do
        @m.meta_og_audio_type.should == "audio/mpeg"
      end
    end
  end

  describe 'Charset detection' do
    it "should get the charset from <meta charset />" do
      @m = MetaInspector::Parser.new(doc 'http://charset001.com')
      @m.charset.should == "utf-8"
    end

    it "should get the charset from meta content type" do
      @m = MetaInspector::Parser.new(doc 'http://charset002.com')
      @m.charset.should == "windows-1252"
    end

    it "should get nil if no declared charset is found" do
      @m = MetaInspector::Parser.new(doc 'http://charset000.com')
      @m.charset.should == nil
    end
  end

  describe 'to_hash' do
    it "should return a hash with all the values set" do
      @m = MetaInspector::Parser.new(doc 'http://pagerankalert.com')
      @m.to_hash.should == { "meta" => { "name" => { "description" => "Track your PageRank(TM) changes and receive alerts by email",
                                                     "keywords"    => "pagerank, seo, optimization, google",
                                                     "robots"      => "all,follow",
                                                     "csrf_param"  => "authenticity_token",
                                                     "csrf_token"  => "iW1/w+R8zrtDkhOlivkLZ793BN04Kr3X/pS+ixObHsE="},
                                         "property"=>{}}}
    end
  end

  private

  def doc(url, options = {})
    MetaInspector::Document.new(url, options)
  end
end
