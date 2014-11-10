require 'spec_helper'

describe MetaInspector do

  describe "#images" do
    it "should find all page images" do
      @m = MetaInspector.new('http://pagerankalert.com')
      @m.images.should == ["http://pagerankalert.com/images/pagerank_alert.png?1305794559"]
    end

    it "should find images on twitter" do
      m = MetaInspector.new('https://twitter.com/markupvalidator')
      m.images.length.should == 6
      m.images.join("; ").should == "https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_reasonably_small.png; https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_normal.png; https://twimg0-a.akamaihd.net/profile_images/2293774732/v0pgo4xpdd9rou2xq5h0_normal.png; https://twimg0-a.akamaihd.net/profile_images/1538528659/jaime_nov_08_normal.jpg; https://si0.twimg.com/sticky/default_profile_images/default_profile_6_mini.png; https://twimg0-a.akamaihd.net/a/1342841381/images/bigger_spinner.gif"
    end

    it "should ignore malformed image tags" do
      # There is an image tag without a source. The scraper should not fatal.
      @m = MetaInspector.new("http://www.guardian.co.uk/media/pda/2011/sep/15/techcrunch-arrington-startups")
      @m.images.size.should == 11
    end
  end

  describe "#image" do
    it "should find the og image" do
      @m = MetaInspector.new('http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')
      @m.image.should == "http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg"
    end

    it "should find image on youtube" do
      MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc').image.should == "http://i2.ytimg.com/vi/iaGSSrp49uc/mqdefault.jpg"
    end

    it "should find image when og:image and twitter:image metatags are missing" do
      MetaInspector.new('http://www.alazan.com').image.should == "http://www.alazan.com/imagenes/logo.jpg"
    end
  end

  describe '#favicon' do
    it "should get favicon link when marked as icon" do
      @m = MetaInspector.new('http://pagerankalert.com/')
      @m.favicon.should == 'http://pagerankalert.com/src/favicon.ico'
    end

    it "should get favicon link when marked as shortcut" do
      @m = MetaInspector.new('http://pagerankalert-shortcut.com/')
      @m.favicon.should == 'http://pagerankalert-shortcut.com/src/favicon.ico'
    end

    it "should get favicon link when marked as shorcut and icon" do
      @m = MetaInspector.new('http://pagerankalert-shortcut-and-icon.com/')
      @m.favicon.should == 'http://pagerankalert-shortcut-and-icon.com/src/favicon.ico'
    end

    it "should get favicon link when there is also a touch icon" do
      @m = MetaInspector.new('http://pagerankalert-touch-icon.com/')
      @m.favicon.should == 'http://pagerankalert-touch-icon.com/src/favicon.ico'
    end

    it "should get favicon link of nil" do
      @m = MetaInspector.new('http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')
      @m.favicon.should == nil
    end
  end
end
