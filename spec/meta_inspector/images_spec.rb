require 'spec_helper'

describe MetaInspector do

  describe "#images" do
    describe "returns an Enumerable" do
      let(:page) { MetaInspector.new('https://twitter.com/markupvalidator') }

      it "responds to #length" do
        expect(page.images.length).to eq(6)
      end

      it "responds to #size" do
        expect(page.images.size).to eq(6)
      end

      it "responds to #each" do
        c = []
        page.images.each {|i| c << i}
        expect(c.length).to eq(6)
      end

      it "responds to #sort" do
        expect(page.images.sort)
          .to eq(["https://si0.twimg.com/sticky/default_profile_images/default_profile_6_mini.png",
                      "https://twimg0-a.akamaihd.net/a/1342841381/images/bigger_spinner.gif",
                      "https://twimg0-a.akamaihd.net/profile_images/1538528659/jaime_nov_08_normal.jpg",
                      "https://twimg0-a.akamaihd.net/profile_images/2293774732/v0pgo4xpdd9rou2xq5h0_normal.png",
                      "https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_normal.png",
                      "https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_reasonably_small.png"])
      end

      it "responds to #first" do
        expect(page.images.first).to eq("https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_reasonably_small.png")
      end

      it "responds to #last" do
        expect(page.images.last).to eq("https://twimg0-a.akamaihd.net/a/1342841381/images/bigger_spinner.gif")
      end

      it "responds to #[]" do
        expect(page.images[0]).to eq("https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_reasonably_small.png")
      end

    end

    it "should find all page images" do
      page = MetaInspector.new('http://pagerankalert.com')

      expect(page.images.to_a).to eq(["http://pagerankalert.com/images/pagerank_alert.png?1305794559"])
    end

    it "should find images on twitter" do
      page = MetaInspector.new('https://twitter.com/markupvalidator')

      expect(page.images.length).to eq(6)
      expect(page.images.to_a).to eq(["https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_reasonably_small.png",
                             "https://twimg0-a.akamaihd.net/profile_images/2380086215/fcu46ozay5f5al9kdfvq_normal.png",
                             "https://twimg0-a.akamaihd.net/profile_images/2293774732/v0pgo4xpdd9rou2xq5h0_normal.png",
                             "https://twimg0-a.akamaihd.net/profile_images/1538528659/jaime_nov_08_normal.jpg",
                             "https://si0.twimg.com/sticky/default_profile_images/default_profile_6_mini.png",
                             "https://twimg0-a.akamaihd.net/a/1342841381/images/bigger_spinner.gif"])
    end

    it "should ignore malformed image tags" do
      # There is an image tag without a source. The scraper should not fatal.
      page = MetaInspector.new("http://www.guardian.co.uk/media/pda/2011/sep/15/techcrunch-arrington-startups")

      expect(page.images.size).to eq(11)
    end
  end

  describe "images.best" do
    it "should find the og image" do
      page = MetaInspector.new('http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')

      expect(page.images.best).to eq("http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg")
    end

    it "should find image on youtube" do
      page = MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc')

      expect(page.images.best).to eq("http://i2.ytimg.com/vi/iaGSSrp49uc/mqdefault.jpg")
    end

    it "should find image when og:image and twitter:image metatags are missing" do
      page = MetaInspector.new('http://example.com/largest_image_using_image_size')

      expect(page.images.best).to eq("http://example.com/100x100")
    end

    it "should find image when some img tag has no src attribute" do
      page = MetaInspector.new('http://example.com/malformed_image_in_html')

      expect(page.images.best).to eq("http://example.com/largest")
    end

  end

  describe "images.owner_suggested" do
    it "should find the og image" do
      page = MetaInspector.new('http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')

      expect(page.images.owner_suggested).to eq("http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg")
    end

    it "should find image on youtube" do
      page = MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc')

      expect(page.images.owner_suggested).to eq("http://i2.ytimg.com/vi/iaGSSrp49uc/mqdefault.jpg")
    end

    it "should return nil when og:image and twitter:image metatags are missing" do
      page = MetaInspector.new('http://example.com/largest_image_using_image_size')

      expect(page.images.owner_suggested).to be nil
    end
  end

  describe "images.largest" do
    it "should find the largest image on the page using html sizes" do
      page = MetaInspector.new('http://example.com/largest_image_in_html')

      expect(page.images.largest).to eq("http://example.com/largest")
    end

    it "should find the largest image on the page using actual image sizes" do
      page = MetaInspector.new('http://example.com/largest_image_using_image_size')

      expect(page.images.largest).to eq("http://example.com/100x100")
    end

    it "should find the largest image without downloading images" do
      page = MetaInspector.new('http://example.com/largest_image_using_image_size', download_images: false)

      expect(page.images.largest).to eq("http://example.com/1x1")
    end
  end

  describe '#favicon' do
    it "should get favicon link when marked as icon" do
      page = MetaInspector.new('http://pagerankalert.com/')

      expect(page.images.favicon).to eq('http://pagerankalert.com/src/favicon.ico')
    end

    it "should get favicon link when marked as shortcut" do
      page = MetaInspector.new('http://pagerankalert-shortcut.com/')

      expect(page.images.favicon).to eq('http://pagerankalert-shortcut.com/src/favicon.ico')
    end

    it "should get favicon link when marked as shorcut and icon" do
      page = MetaInspector.new('http://pagerankalert-shortcut-and-icon.com/')

      expect(page.images.favicon).to eq('http://pagerankalert-shortcut-and-icon.com/src/favicon.ico')
    end

    it "should get favicon link when there is also a touch icon" do
      page = MetaInspector.new('http://pagerankalert-touch-icon.com/')

      expect(page.images.favicon).to eq('http://pagerankalert-touch-icon.com/src/favicon.ico')
    end

    it "should get favicon link of nil" do
      page = MetaInspector.new('http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')

      expect(page.images.favicon).to eq(nil)
    end
  end
end
