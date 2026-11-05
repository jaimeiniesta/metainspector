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
    it 'should prefer the Parsely image over the largest image' do
      html = '<meta name="parsely-image-url" content="/parsely.jpg"><img src="/largest.jpg" width="100" height="100">'
      page = MetaInspector.new('http://example.com/', document: html)

      expect(page.images.best).to eq('http://example.com/parsely.jpg')
    end

    ['', '  &#10;  '].each do |value|
      it "should fall back to the largest image when the Parsely image is empty (#{value.inspect})" do
        html = %(<meta name="parsely-image-url" content="#{value}"><img src="/largest.jpg" width="100" height="100">)
        page = MetaInspector.new('http://example.com/', document: html)

        expect(page.images.best).to eq('http://example.com/largest.jpg')
      end
    end

    it "should find a valid image when another image URL cannot be parsed" do
      html = '<html><body><img src="http://exa mple.com/x.png"><img src="/100x100"></body></html>'
      page = MetaInspector.new('http://example.com/', document: html)

      allow(FastImage).to receive(:size).and_call_original
      expect(FastImage).not_to receive(:size).with(nil)
      expect(page.images.best).to eq("http://example.com/100x100")
    end

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

    it "should find image when og:image and twitter:image metatags are present but empty" do
      page = MetaInspector.new('http://example.com/meta_tags_empty')

      expect(page.images.best).to eq("http://example.com/100x100")
    end

    it "should find image when some img tag has no src attribute" do
      page = MetaInspector.new('http://example.com/malformed_image_in_html')

      expect(page.images.best).to eq("http://example.com/largest")
    end

  end

  describe "images.owner_suggested" do
    it 'should find the Parsely image when no existing metadata is present' do
      html = '<meta name="parsely-image-url" content="https://images.example.com/parsely.jpg?b=2&amp;a=1">'
      page = MetaInspector.new('http://example.com/', document: html)

      expect(page.images.owner_suggested).to eq('https://images.example.com/parsely.jpg?b=2&a=1')
    end

    it 'should resolve a relative Parsely image against the document base URL' do
      html = '<base href="/assets/"><meta name="parsely-image-url" content="parsely.jpg">'
      page = MetaInspector.new('http://example.com/articles/page', document: html)

      expect(page.images.owner_suggested).to eq('http://example.com/assets/parsely.jpg')
    end

    it 'should use the Parsely image when existing metadata is empty' do
      html = '<meta property="og:image" content=""><meta name="twitter:image" content=""><meta name="parsely-image-url" content="/parsely.jpg">'
      page = MetaInspector.new('http://example.com/', document: html)

      expect(page.images.owner_suggested).to eq('http://example.com/parsely.jpg')
    end

    ['og:image', 'twitter:image'].each do |candidate|
      it "should prefer #{candidate} over the Parsely image" do
        html = %(<meta name="parsely-image-url" content="/parsely.jpg"><meta property="#{candidate}" content="/existing.jpg">)
        page = MetaInspector.new('http://example.com/', document: html)

        expect(page.images.owner_suggested).to eq('http://example.com/existing.jpg')
      end
    end

    ['', '  &#10;  '].each do |value|
      it "should ignore an empty Parsely image (#{value.inspect})" do
        page = MetaInspector.new('http://example.com/', document: %(<meta name="parsely-image-url" content="#{value}">))

        expect(page.images.owner_suggested).to be_nil
      end
    end

    it "should find the og image" do
      page = MetaInspector.new('http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/')

      expect(page.images.owner_suggested).to eq("http://o.onionstatic.com/images/articles/article/2772/Apple-Claims-600w-R_jpg_130x110_q85.jpg")
    end

    it "should find image on youtube" do
      page = MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc')

      expect(page.images.owner_suggested).to eq("http://i2.ytimg.com/vi/iaGSSrp49uc/mqdefault.jpg")
    end

    it "should absolutify image" do
      page = MetaInspector.new('http://www.24-horas.mx/mexico-firma-acuerdo-bilateral-automotriz-con-argentina/')

      expect(page.images.owner_suggested).to eq("http://www.24-horas.mx/wp-content/uploads/2015/03/50316106.jpg")
    end

    it "should return nil when og:image and twitter:image metatags are missing" do
      page = MetaInspector.new('http://example.com/largest_image_using_image_size')

      expect(page.images.owner_suggested).to be nil
    end

    it "should not normalize image" do
      page = MetaInspector.new("http://www.guardian.co.uk/media/pda/2011/sep/15/techcrunch-arrington-startups")

      expect(page.images.owner_suggested).to eq("https://i.guim.co.uk/img/media/020bf03ae1d259626803b6c83ac57fd57382f285/0_102_5760_3456/master/5760.jpg?width=1200&height=630&quality=85&auto=format&fit=crop&overlay-align=bottom%2Cleft&overlay-width=100p&overlay-base64=L2ltZy9zdGF0aWMvb3ZlcmxheXMvdGctZGVmYXVsdC5wbmc&s=46e054247285bdf48a7621d371fc5070")
    end
  end

  describe "images.with_size" do
    describe "max_image_downloads" do
      let(:html) do
        '<img src="/10x10"><img src="/100x100"><img src="/remaining.jpg">'
      end

      before do
        stub_request(:get, 'http://example.com/remaining.jpg').to_return(status: 404)
      end

      it "should download only the first images needing dimensions in document order" do
        page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: 2)

        expect(page.images.with_size).to eq([
          ['http://example.com/100x100', 100, 100],
          ['http://example.com/10x10', 10, 10],
          ['http://example.com/remaining.jpg', 0, 0]
        ])
        expect(WebMock).to have_requested(:get, 'http://example.com/10x10').once
        expect(WebMock).to have_requested(:get, 'http://example.com/100x100').once
        expect(WebMock).not_to have_requested(:get, 'http://example.com/remaining.jpg')
      end

      it "should preserve HTML dimensions without consuming the download budget" do
        html = '<img src="/known.jpg" width="200" height="200"><img src="/10x10"><img src="/100x100"><img src="/later.jpg" width="300" height="300">'
        page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: 1)

        expect(page.images.with_size).to eq([
          ['http://example.com/later.jpg', 300, 300],
          ['http://example.com/known.jpg', 200, 200],
          ['http://example.com/10x10', 10, 10],
          ['http://example.com/100x100', 0, 0]
        ])
        expect(WebMock).to have_requested(:get, 'http://example.com/10x10').once
        expect(WebMock).not_to have_requested(:get, 'http://example.com/100x100')
      end

      it "should exclude invalid and duplicate URLs before consuming the budget" do
        html = '<img src="http://exa mple.com/broken.jpg"><img src="/10x10"><img src="http://example.com/10x10"><img src="/100x100"><img src="/remaining.jpg">'
        page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: 2)

        expect(page.images.with_size).to eq([
          ['http://example.com/100x100', 100, 100],
          ['http://example.com/10x10', 10, 10],
          ['http://example.com/remaining.jpg', 0, 0]
        ])
        expect(WebMock).to have_requested(:get, 'http://example.com/10x10').once
        expect(WebMock).to have_requested(:get, 'http://example.com/100x100').once
        expect(WebMock).not_to have_requested(:get, 'http://example.com/remaining.jpg')
      end

      it "should treat an image missing one HTML dimension as needing a download" do
        html = '<img src="/10x10" width="500"><img src="/100x100" height="500">'
        page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: 1)

        expect(page.images.with_size).to eq([
          ['http://example.com/10x10', 10, 10],
          ['http://example.com/100x100', 0, 0]
        ])
        expect(WebMock).to have_requested(:get, 'http://example.com/10x10').once
        expect(WebMock).not_to have_requested(:get, 'http://example.com/100x100')
      end

      it "should disable downloads with a zero limit while preserving HTML dimensions" do
        html = '<img src="/10x10"><img src="/known.jpg" width="200" height="100">'
        page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: 0)

        expect(page.images.with_size).to eq([
          ['http://example.com/known.jpg', 200, 100],
          ['http://example.com/10x10', 0, 0]
        ])
        expect(WebMock).not_to have_requested(:get, 'http://example.com/10x10')
      end

      it "should respect download_images: false even with a positive limit" do
        page = MetaInspector.new('http://example.com/', document: html, download_images: false, max_image_downloads: 2)

        expect(page.images.with_size).to eq([
          ['http://example.com/10x10', 0, 0],
          ['http://example.com/100x100', 0, 0],
          ['http://example.com/remaining.jpg', 0, 0]
        ])
        expect(WebMock).not_to have_requested(:get, %r{http://example.com/})
      end

      [nil, 10].each do |limit|
        it "should download every candidate when the limit is #{limit.inspect}" do
          page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: limit)

          expect(page.images.with_size).to eq([
            ['http://example.com/100x100', 100, 100],
            ['http://example.com/10x10', 10, 10],
            ['http://example.com/remaining.jpg', 0, 0]
          ])
          expect(WebMock).to have_requested(:get, 'http://example.com/10x10').once
          expect(WebMock).to have_requested(:get, 'http://example.com/100x100').once
          expect(WebMock).to have_requested(:get, 'http://example.com/remaining.jpg').once
        end
      end

      [:not_found, :invalid_image, :timeout].each do |failure|
        it "should count a #{failure} image attempt toward the limit" do
          request = stub_request(:get, 'http://example.com/broken.jpg')
          case failure
          when :not_found then request.to_return(status: 404)
          when :invalid_image then request.to_return(body: 'not an image')
          when :timeout then request.to_timeout
          end
          html = '<img src="/broken.jpg"><img src="/100x100">'
          page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: 1)

          expect(page.images.with_size).to eq([
            ['http://example.com/broken.jpg', 0, 0],
            ['http://example.com/100x100', 0, 0]
          ])
          expect(request).to have_been_requested.once
          expect(WebMock).not_to have_requested(:get, 'http://example.com/100x100')
        end
      end

      it "should reuse the limited results for repeated size and best-image queries" do
        page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: 1)

        2.times do
          expect(page.images.with_size.first).to eq(['http://example.com/10x10', 10, 10])
          expect(page.images.largest).to eq('http://example.com/10x10')
          expect(page.images.best).to eq('http://example.com/10x10')
        end
        expect(WebMock).to have_requested(:get, 'http://example.com/10x10').once
        expect(WebMock).not_to have_requested(:get, 'http://example.com/100x100')
      end

      it "should keep the budget local to each document" do
        2.times do
          page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: 1)

          expect(page.images.with_size.first).to eq(['http://example.com/10x10', 10, 10])
        end
        expect(WebMock).to have_requested(:get, 'http://example.com/10x10').twice
        expect(WebMock).not_to have_requested(:get, 'http://example.com/100x100')
      end

      it "should keep all image URLs without downloading them when enumerating images" do
        page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: 1)

        expect(page.images.to_a).to eq([
          'http://example.com/10x10',
          'http://example.com/100x100',
          'http://example.com/remaining.jpg'
        ])
        expect(WebMock).not_to have_requested(:get, %r{http://example.com/})
      end
    end

    [true, false].each do |download_images|
      it "should ignore unparseable image URLs with download_images: #{download_images}" do
        html = '<html><body><img src="http://exa mple.com/x.png"><img src="/valid.png" width="100" height="100"></body></html>'
        page = MetaInspector.new('https://example.com/', document: html, download_images: download_images)

        expect(FastImage).not_to receive(:size).with(nil)
        expect(page.images.with_size).to eq([["https://example.com/valid.png", 100, 100]])
      end
    end

    it "should ignore unparseable image URLs even when HTML sizes are present" do
      html = '<html><body><img src="http://exa mple.com/x.png" width="100" height="100"></body></html>'
      page = MetaInspector.new('https://example.com/', document: html)

      expect(page.images.with_size).to eq([])
    end

    it "should return sorted by area array of [img_url, width, height] using html sizes" do
      page = MetaInspector.new('http://example.com/largest_image_in_html')

      expect(page.images.with_size).to eq([
        ["http://example.com/largest", 100, 100],
        ["http://example.com/too_narrow", 10, 100],
        ["http://example.com/too_wide", 100, 10],
        ["http://example.com/smaller", 10, 10],
        ["http://example.com/smallest", 1, 1]
      ])
    end

    it "should return sorted by area array of [img_url, width, height] using actual image sizes" do
      page = MetaInspector.new('http://example.com/largest_image_using_image_size')

      expect(page.images.with_size).to eq([
        ["http://example.com/100x100", 100, 100],
        ["http://example.com/10x100", 10, 100],
        ["http://example.com/100x10", 100, 10],
        ["http://example.com/10x10", 10, 10],
        ["http://example.com/1x1", 1, 1]
      ])
    end

    it "should return sorted by area array of [img_url, width, height] without downloading images" do
      page = MetaInspector.new('http://example.com/largest_image_using_image_size', download_images: false)

      expect(page.images.with_size).to eq([
        ["http://example.com/10x100", 10, 100],
        ["http://example.com/100x10", 100, 10],
        ["http://example.com/1x1", 1, 1],
        ["http://example.com/10x10", 0, 0],
        ["http://example.com/100x100", 0, 0]
      ])
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

  describe 'protocol-relative' do
    before(:each) do
      @m_http   = MetaInspector.new('http://protocol-relative.com')
      @m_https  = MetaInspector.new('https://protocol-relative.com')
    end

    it 'should unrelativize images' do
      expect(@m_http.images.to_a).to eq(['http://example.com/image.jpg'])
      expect(@m_https.images.to_a).to eq(['https://example.com/image.jpg'])
    end

    it 'should unrelativize owner suggested image' do
      expect(@m_http.images.owner_suggested).to eq('http://static-secure.guim.co.uk/sys-images/Guardian/Pix/pictures/2011/8/8/1312810126887/gu_192x115.jpg')
      expect(@m_https.images.owner_suggested).to eq('https://static-secure.guim.co.uk/sys-images/Guardian/Pix/pictures/2011/8/8/1312810126887/gu_192x115.jpg')
    end

    it 'should unrelativize favicon' do
      expect(@m_http.images.favicon).to eq('http://static-secure.guim.co.uk/sys-images/favicon.ico')
      expect(@m_https.images.favicon).to eq('https://static-secure.guim.co.uk/sys-images/favicon.ico')
    end
  end
end
