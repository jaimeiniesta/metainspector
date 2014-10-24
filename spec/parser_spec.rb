require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector::Parser do
  let(:logger) { MetaInspector::ExceptionLog.new }

  describe 'Doing a basic scrape' do

    before(:each) do
      @m = MetaInspector::Parser.new(doc 'http://pagerankalert.com')
    end

    describe "get image" do
      it "should find the og image" do
        @m = MetaInspector::Parser.new(doc 'http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')
        @m.image.should == "http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg"
      end

      it "should find image on youtube" do
        MetaInspector::Parser.new(doc 'http://www.youtube.com/watch?v=iaGSSrp49uc').image.should == "http://i2.ytimg.com/vi/iaGSSrp49uc/mqdefault.jpg"
      end

      it "should find image when og:image and twitter:image metatags are missing" do
        MetaInspector::Parser.new(doc 'http://www.alazan.com').image.should == "http://www.alazan.com/imagenes/logo.jpg"
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

  end

  it "should get the title from the head section" do
    p = MetaInspector::Parser.new(doc 'http://example.com')
    p.title.should == 'An example page'
  end

  describe '#description' do
    it "should find description from meta description" do
      page = MetaInspector::Parser.new(doc 'http://www.youtube.com/watch?v=iaGSSrp49uc')

      page.description.should == "This is Youtube"
    end

    it "should find a secondary description if no meta description" do
      @m = MetaInspector::Parser.new(doc 'http://theonion-no-description.com')
      @m.description.should == "SAN FRANCISCO—In a move expected to revolutionize the mobile device industry, Apple launched its fastest and most powerful iPhone to date Tuesday, an innovative new model that can only be seen by the company's hippest and most dedicated customers. This is secondary text picked up because of a missing meta description."
    end
  end

  describe '#favicon' do
    it "should get favicon link when marked as icon" do
      @m = MetaInspector::Parser.new(doc 'http://pagerankalert.com/')
      @m.favicon.should == 'http://pagerankalert.com/src/favicon.ico'
    end

    it "should get favicon link when marked as shortcut" do
      @m = MetaInspector::Parser.new(doc 'http://pagerankalert-shortcut.com/')
      @m.favicon.should == 'http://pagerankalert-shortcut.com/src/favicon.ico'
    end

    it "should get favicon link when marked as shorcut and icon" do
      @m = MetaInspector::Parser.new(doc 'http://pagerankalert-shortcut-and-icon.com/')
      @m.favicon.should == 'http://pagerankalert-shortcut-and-icon.com/src/favicon.ico'
    end

    it "should get favicon link when there is also a touch icon" do
      @m = MetaInspector::Parser.new(doc 'http://pagerankalert-touch-icon.com/')
      @m.favicon.should == 'http://pagerankalert-touch-icon.com/src/favicon.ico'
    end

    it "should get favicon link of nil" do
      @m = MetaInspector::Parser.new(doc 'http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')
      @m.favicon.should == nil
    end
  end

  describe 'Getting meta tags' do
    let(:page) { MetaInspector::Parser.new(doc 'http://example.com/meta-tags') }

    it "#meta_tags" do
      page.meta_tags.should == {
                                  'name' => {
                                              'keywords'       => ['one, two, three'],
                                              'description'    => ['the description'],
                                              'author'         => ['Joe Sample'],
                                              'robots'         => ['index,follow'],
                                              'revisit'        => ['15 days'],
                                              'dc.date.issued' => ['2011-09-15']
                                             },

                                  'http-equiv' => {
                                                    'content-type'        => ['text/html; charset=UTF-8'],
                                                    'content-style-type'  => ['text/css']
                                                  },

                                  'property' => {
                                                  'og:title'        => ['An OG title'],
                                                  'og:type'         => ['website'],
                                                  'og:url'          => ['http://example.com/meta-tags'],
                                                  'og:image'        => ['http://example.com/rock.jpg',
                                                                        'http://example.com/rock2.jpg',
                                                                        'http://example.com/rock3.jpg'],
                                                  'og:image:width'  => ['300'],
                                                  'og:image:height' => ['300', '1000']
                                                },

                                  'charset' => ['UTF-8']
                                }
    end

    it "#meta_tag" do
      page.meta_tag.should == {
                                  'name' => {
                                              'keywords'       => 'one, two, three',
                                              'description'    => 'the description',
                                              'author'         => 'Joe Sample',
                                              'robots'         => 'index,follow',
                                              'revisit'        => '15 days',
                                              'dc.date.issued' => '2011-09-15'
                                             },

                                  'http-equiv' => {
                                                    'content-type'        => 'text/html; charset=UTF-8',
                                                    'content-style-type'  => 'text/css'
                                                  },

                                  'property' => {
                                                  'og:title'        => 'An OG title',
                                                  'og:type'         => 'website',
                                                  'og:url'          => 'http://example.com/meta-tags',
                                                  'og:image'        => 'http://example.com/rock.jpg',
                                                  'og:image:width'  => '300',
                                                  'og:image:height' => '300'
                                                },

                                  'charset' => 'UTF-8'
                                }
    end

    it "#meta" do
      page.meta.should == {
                            'keywords'            => 'one, two, three',
                            'description'         => 'the description',
                            'author'              => 'Joe Sample',
                            'robots'              => 'index,follow',
                            'revisit'             => '15 days',
                            'dc.date.issued'      => '2011-09-15',
                            'content-type'        => 'text/html; charset=UTF-8',
                            'content-style-type'  => 'text/css',
                            'og:title'            => 'An OG title',
                            'og:type'             => 'website',
                            'og:url'              => 'http://example.com/meta-tags',
                            'og:image'            => 'http://example.com/rock.jpg',
                            'og:image:width'      => '300',
                            'og:image:height'     => '300',
                            'charset'             => 'UTF-8'
                          }
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

  private

  def doc(url, options = { exception_log: logger })
    MetaInspector::Document.new(url, options)
  end
end
