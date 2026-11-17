require 'spec_helper'

describe 'noscript content' do
  let(:page) { MetaInspector.new('https://example.com/', document: html, download_images: false) }

  describe 'in the head' do
    [
      '<img src="/pixel.gif">',
      '<iframe src="/tracking"></iframe>',
      '<a href="/fallback">Fallback</a>',
      '<div>Enable JavaScript</div>',
      'Enable JavaScript'
    ].each do |content|
      context "containing #{content}" do
        let(:html) do
          <<~HTML
            <html><head>
              <noscript>#{content}</noscript>
              <title>My page</title>
              <link rel="canonical" href="https://example.com/">
              <link rel="stylesheet" href="/style.css">
            </head><body><h1>Heading</h1></body></html>
          HTML
        end

        it 'preserves the title and head links after the fallback' do
          expect(page.title).to eq('My page')
          expect(page.canonicals).to eq([{ rel: 'canonical', href: 'https://example.com/' }])
          expect(page.stylesheets).to eq([{ rel: 'stylesheet', href: 'https://example.com/style.css' }])
          expect(page.head_links.size).to eq(2)
        end
      end
    end
  end

  describe 'with an unclosed iframe' do
    ['<iframe src="/tracking">', '<iframe src="/tracking" />'].each do |iframe|
      ['head', 'body'].each do |location|
        context "in the #{location}, written as #{iframe}" do
          let(:html) do
            fallback = "<noscript>#{iframe}</noscript>"
            <<~HTML
              <html><head>
                #{fallback if location == 'head'}
                <title>My page</title>
              </head><body>
                #{fallback if location == 'body'}
                <h1>Heading</h1>
                <a href="/about">About</a>
                <img src="/photo.jpg">
              </body></html>
            HTML
          end

          it 'preserves the rest of the page and the fallback iframe' do
            expect(page.title).to eq('My page')
            expect(page.h1).to eq(['Heading'])
            expect(page.links.raw).to eq(['/about'])
            expect(page.images.to_a).to eq(['https://example.com/photo.jpg'])
            expect(page.iframes).to eq([{ src: '/tracking' }])
            expect(page.iframe_sources).to eq(['https://example.com/tracking'])
          end
        end
      end
    end
  end

  describe 'fallback extraction' do
    let(:html) do
      <<~HTML
        <html><head>
          <base href="https://example.com/assets/">
          <link rel="preload" href="style.css" as="style">
          <noscript>
            <link rel="stylesheet" href="style.css">
            <link rel="alternate" type="application/rss+xml" href="feed.xml">
            <link rel="icon" href="icon.png">
            <img src="pixel.gif" width="1" height="1">
          </noscript>
          <title>Café &amp; news</title>
        </head><body>
          <a href="before">Before</a>
          <noscript>
            <h1>Café &amp; news</h1>
            <a href="fallback?x=1&amp;y=2">Fallback</a>
            <img src="photo.jpg" srcset="photo-2x.jpg 2x" width="640" height="480">
            <iframe src="video?x=1&amp;y=2" title="Café &amp; news"></iframe>
            <link rel="stylesheet" href="body.css">
          </noscript>
          <a href="after">After</a>
          <img src="after.jpg" width="100" height="100">
          <iframe src="after-video"></iframe>
        </body></html>
      HTML
    end

    it 'preserves head fallback stylesheets without including body stylesheets' do
      expect(page.stylesheets).to eq([{ rel: 'stylesheet', href: 'https://example.com/assets/style.css' }])
      expect(page.head_links.size).to eq(4)
      expect(page.feeds).to eq([
        { title: nil, href: 'https://example.com/assets/feed.xml', type: 'application/rss+xml' }
      ])
      expect(page.images.favicon).to eq('https://example.com/assets/icon.png')
    end

    it 'preserves fallback links and their order, resolving against the document base' do
      expect(page.links.raw).to eq(['before', 'fallback?x=1&y=2', 'after'])
      expect(page.links.all).to eq([
        'https://example.com/assets/before', 'https://example.com/assets/fallback?x=1&y=2',
        'https://example.com/assets/after'
      ])
    end

    it 'preserves fallback images, responsive candidates and dimensions' do
      expect(page.images.to_a).to eq(%w[pixel.gif photo.jpg photo-2x.jpg after.jpg].map do |name|
        "https://example.com/assets/#{name}"
      end)
      expect(page.images.with_size.first).to eq(['https://example.com/assets/photo.jpg', 640, 480])
    end

    it 'preserves fallback iframes and decodes entities once' do
      expect(page.iframes).to eq([
        { src: 'video?x=1&y=2', title: 'Café & news' }, { src: 'after-video' }
      ])
      expect(page.iframe_sources).to eq([
        'https://example.com/assets/video?x=1&y=2', 'https://example.com/assets/after-video'
      ])
      expect(page.title).to eq('Café & news')
      expect(page.h1).to eq(['Café & news'])
    end

    it 'keeps fallback nodes in the public DOM and preserves the frozen source' do
      original = html.dup
      html.freeze

      expect(page.parsed.css('head noscript img').size).to eq(1)
      expect(page.parsed.css('body noscript a').size).to eq(1)
      expect(page.to_s).to equal(html)
      expect(html).to eq(original)
    end

    it 'applies the same parsing to a downloaded document' do
      stub_request(:get, 'https://example.com/').to_return(body: html, headers: { 'Content-Type' => 'text/html' })
      downloaded = MetaInspector.new('https://example.com/', download_images: false)

      expect(downloaded.title).to eq(page.title)
      expect(downloaded.head_links).to eq(page.head_links)
      expect(downloaded.to_hash['images']).to eq(page.images.to_a)
    end
  end

  it 'does not treat noscript-like text in scripts or comments as fallback markup' do
    html = <<~HTML
      <head><script>var fallback = '<noscript><img src="/fake.jpg"></noscript>';</script>
      <!-- <noscript><img src="/comment.jpg"></noscript> -->
      <title>My page</title></head><body><img src="/photo.jpg"></body>
    HTML
    page = MetaInspector.new('https://example.com/', document: html, download_images: false)

    expect(page.title).to eq('My page')
    expect(page.images.to_a).to eq(['https://example.com/photo.jpg'])
  end

  it 'does not introduce an attribute count limit for fallback content' do
    attributes = (1..500).map { |i| "data-#{i}=\"#{i}\"" }.join(' ')
    html = "<noscript><a href=\"/fallback\" #{attributes}>Fallback</a></noscript>"
    page = MetaInspector.new('https://example.com/', document: html)

    expect(page.links.raw).to eq(['/fallback'])
  end

  it 'wraps HTML5 depth-limit errors in fallback fragments' do
    html = '<noscript>' + '<div><h1><p>' * 220 + 'deep</noscript><h1>After</h1>'

    expect do
      MetaInspector.new('https://example.com/', document: html)
    end.to raise_error(MetaInspector::ParserError, /tree depth limit/)
  end
end
