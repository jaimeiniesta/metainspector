require 'spec_helper'

describe MetaInspector do
  let(:page)   { MetaInspector.new('http://example.com') }

  describe '#links' do
    it 'returns the internal links' do
      page.links.internal.should == [ "http://example.com/",
                                        "http://example.com/faqs",
                                        "http://example.com/contact",
                                        "http://example.com/team.html" ]
    end

    it 'returns the external links' do
      page.links.external.should == [ "https://twitter.com/",
                                        "https://github.com/" ]
    end

    it 'returns the non-HTTP links' do
      page.links.non_http.should == [ "mailto:hello@example.com",
                                        "javascript:alert('hi');",
                                        "ftp://ftp.example.com/" ]
    end
  end

  describe 'Links' do
    before(:each) do
      @m = MetaInspector.new('http://pagerankalert.com')
    end

    it "should get correct absolute links for internal pages" do
      @m.links.internal.should == [ "http://pagerankalert.com/",
                                      "http://pagerankalert.com/es?language=es",
                                      "http://pagerankalert.com/users/sign_up",
                                      "http://pagerankalert.com/users/sign_in" ]
    end

    it "should get correct absolute links for external pages" do
      @m.links.external.should == [ "http://pagerankalert.posterous.com/",
                                      "http://twitter.com/pagerankalert",
                                      "http://twitter.com/share" ]
    end

    it "should get correct absolute links, correcting relative links from URL not ending with slash" do
      m = MetaInspector.new('http://alazan.com/websolution.asp')

      m.links.internal.should == [ "http://alazan.com/index.asp",
                                     "http://alazan.com/faqs.asp" ]
    end

    describe "links with international characters" do
      it "should get correct absolute links, encoding the URLs as needed" do
        m = MetaInspector.new('http://international.com')

        m.links.internal.should == [ "http://international.com/espa%C3%B1a.asp",
                                       "http://international.com/roman%C3%A9e",
                                       "http://international.com/faqs#cami%C3%B3n",
                                       "http://international.com/search?q=cami%C3%B3n",
                                       "http://international.com/search?q=espa%C3%B1a#top",
                                       "http://international.com/index.php?q=espa%C3%B1a&url=aHR0zZQ==&cntnt01pageid=21"]

        m.links.external.should == [ "http://example.com/espa%C3%B1a.asp",
                                       "http://example.com/roman%C3%A9e",
                                       "http://example.com/faqs#cami%C3%B3n",
                                       "http://example.com/search?q=cami%C3%B3n",
                                       "http://example.com/search?q=espa%C3%B1a#top"]
      end

      describe "internal links" do
        it "should get correct internal links, encoding the URLs as needed but respecting # and ?" do
          m = MetaInspector.new('http://international.com')
          m.links.internal.should == [ "http://international.com/espa%C3%B1a.asp",
                                       "http://international.com/roman%C3%A9e",
                                       "http://international.com/faqs#cami%C3%B3n",
                                       "http://international.com/search?q=cami%C3%B3n",
                                       "http://international.com/search?q=espa%C3%B1a#top",
                                       "http://international.com/index.php?q=espa%C3%B1a&url=aHR0zZQ==&cntnt01pageid=21"]
        end

        it "should not crash when processing malformed hrefs" do
          m = MetaInspector.new('http://example.com/malformed_href')
          m.links.internal.should == [ "http://example.com/faqs" ]
        end
      end

      describe "external links" do
        it "should get correct external links, encoding the URLs as needed but respecting # and ?" do
          m = MetaInspector.new('http://international.com')
          m.links.external.should == [ "http://example.com/espa%C3%B1a.asp",
                                       "http://example.com/roman%C3%A9e",
                                       "http://example.com/faqs#cami%C3%B3n",
                                       "http://example.com/search?q=cami%C3%B3n",
                                       "http://example.com/search?q=espa%C3%B1a#top"]
        end

        it "should not crash when processing malformed hrefs" do
          m = MetaInspector.new('http://example.com/malformed_href')
          m.links.non_http.should == ["skype:joeuser?call", "telnet://telnet.cdrom.com", "javascript:alert('ok');",
                                        "javascript://", "mailto:email(at)example.com"]
        end
      end
    end

    it "should not crash with links that have weird href values" do
      m = MetaInspector.new('http://example.com/invalid_href')
      m.links.non_http.should == ["%3Cp%3Eftp://ftp.cdrom.com", "skype:joeuser?call", "telnet://telnet.cdrom.com"]
    end
  end

  describe 'Relative links' do
    describe 'From a root URL' do
      before(:each) do
        @m = MetaInspector.new('http://relative.com/')
      end

      it 'should get the relative links' do
        @m.links.internal.should == ['http://relative.com/about', 'http://relative.com/sitemap']
      end
    end

    describe 'From a document' do
      before(:each) do
        @m = MetaInspector.new('http://relative.com/company')
      end

      it 'should get the relative links' do
        @m.links.internal.should == ['http://relative.com/about', 'http://relative.com/sitemap']
      end
    end

    describe 'From a directory' do
      before(:each) do
        @m = MetaInspector.new('http://relative.com/company/')
      end

      it 'should get the relative links' do
        @m.links.internal.should == ['http://relative.com/company/about', 'http://relative.com/sitemap']
      end
    end
  end

  describe 'Relative links with base' do
    it 'should get the relative links from a document' do
      m = MetaInspector.new('http://relativewithbase.com/company/page2')
      m.links.internal.should == ['http://relativewithbase.com/about', 'http://relativewithbase.com/sitemap']
    end

    it 'should get the relative links from a directory' do
      m = MetaInspector.new('http://relativewithbase.com/company/page2/')
      m.links.internal.should == ['http://relativewithbase.com/about', 'http://relativewithbase.com/sitemap']
    end
  end

  describe 'Non-HTTP links' do
    before(:each) do
      @m = MetaInspector.new('http://example.com/nonhttp')
    end

    it "should get the links" do
      @m.links.non_http.sort.should == [
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
      @m_http   = MetaInspector.new('http://protocol-relative.com')
      @m_https  = MetaInspector.new('https://protocol-relative.com')
    end

    it "should convert protocol-relative links to http" do
      @m_http.links.internal.should include('http://protocol-relative.com/contact')
      @m_http.links.external.should include('http://yahoo.com/')
    end

    it "should convert protocol-relative links to https" do
      @m_https.links.internal.should include('https://protocol-relative.com/contact')
      @m_https.links.external.should include('https://yahoo.com/')
    end
  end

  describe "Feed" do
    it "should get rss feed" do
      @m = MetaInspector.new('http://www.iteh.at')
      @m.feed.should == 'http://www.iteh.at/de/rss/'
    end

    it "should get atom feed" do
      @m = MetaInspector.new('http://www.tea-tron.com/jbravo/blog/')
      @m.feed.should == 'http://www.tea-tron.com/jbravo/blog/feed/'
    end

    it "should return nil if no feed found" do
      @m = MetaInspector.new('http://www.alazan.com')
      @m.feed.should == nil
    end
  end
end
