require 'spec_helper'

describe MetaInspector do
  describe "head_links" do
    let(:page) { MetaInspector.new('http://example.com/head_links') }
    let(:page_https) { MetaInspector.new('https://example.com/head_links') }

    it "#head_links" do
      expect(page.head_links).to eq([
                                        {rel: 'canonical', href: 'http://example.com/canonical-from-head'},
                                        {rel: 'stylesheet', href: 'http://example.com/stylesheets/screen.css'},
                                        {rel: 'stylesheet', href: 'http://example2.com/stylesheets/screen.css'},
                                        {rel: 'shortcut icon', href: 'http://example.com/favicon.ico', type: 'image/x-icon'},
                                        {rel: 'shorturl', href: 'http://gu.com/p/32v5a'},
                                        {rel: 'stylesheet', type: 'text/css', href: 'http://foo/print.css', media: 'print', class: 'contrast'}
                                    ])
    end

    it "#stylesheets" do
      expect(page.stylesheets).to eq([
                                         {rel: 'stylesheet', href: 'http://example.com/stylesheets/screen.css'},
                                         {rel: 'stylesheet', href: 'http://example2.com/stylesheets/screen.css'},
                                         {rel: 'stylesheet', type: 'text/css', href: 'http://foo/print.css', media: 'print', class: 'contrast'}
                                     ])

      expect(page_https.stylesheets).to eq([
                                         {rel: 'stylesheet', href: 'https://example.com/stylesheets/screen.css'},
                                         {rel: 'stylesheet', href: 'https://example2.com/stylesheets/screen.css'},
                                         {rel: 'stylesheet', type: 'text/css', href: 'http://foo/print.css', media: 'print', class: 'contrast'}
                                     ])
    end

    it "#canonical" do
      expect(page.canonicals).to eq([
                                        {rel: 'canonical', href: 'http://example.com/canonical-from-head'}
                                    ])
    end

    context "on page with some broken feed links" do
      let(:page){ MetaInspector.new('http://example.com/broken_head_links') }
      it "tries to find correct one" do
        expected = [
          { title: "TechCrunch RSS feed", href: "http://www.guardian.co.uk/media/techcrunch/rss", type: "application/rss+xml" }
        ]
        expect(page.feeds).to eq(expected)
      end
    end
  end

  describe "rel token matching" do
    { feeds: 'alternate', stylesheets: 'stylesheet', canonicals: 'canonical' }.each do |method, keyword|
      describe "##{method}" do
        let(:document) do
          %(<html><head><link #{rel_attribute} type="application/rss+xml" title="Example" href="/resource"></head></html>)
        end
        let(:page) { MetaInspector.new('https://example.com/page', document: document) }
        let(:expected_link) do
          attributes = { title: 'Example', href: 'https://example.com/resource', type: 'application/rss+xml' }
          attributes[:rel] = rel.gsub(/\r\n?/, "\n") unless method == :feeds
          attributes
        end

        [keyword, "#{keyword} nofollow", "nofollow #{keyword}", keyword.upcase,
         "nofollow #{keyword.capitalize}", " #{keyword}  nofollow ",
         "#{keyword} #{keyword}", "nofollow\t#{keyword}", "nofollow\n#{keyword}",
         "nofollow\f#{keyword}", "nofollow\r#{keyword}"].each do |value|
          context "with rel=#{value.inspect}" do
            let(:rel) { value }
            let(:rel_attribute) { %(rel="#{rel}") }

            it "matches the complete token and preserves the parsed link attributes" do
              expect(page.public_send(method)).to eq([expected_link])
              expect(page.head_links.first[:rel]).to eq(rel.gsub(/\r\n?/, "\n"))
            end
          end
        end

        [nil, '', 'nofollow', "not-#{keyword}", "#{keyword}-extra",
         "nofollow,#{keyword}", "nofollow&#160;#{keyword}", "nofollow&#11;#{keyword}"].each do |value|
          context "with rel=#{value.inspect}" do
            let(:rel_attribute) { value.nil? ? '' : %(rel="#{value}") }

            it "does not match a missing or incomplete token" do
              expect(page.public_send(method)).to eq([])
            end
          end
        end
      end
    end
  end

  describe "feeds with combined rel tokens" do
    let(:page) { MetaInspector.new('https://example.com/page', document: document) }
    let(:document) do
      <<~HTML
        <html><head>
          <base href="https://feeds.example.com/blog/">
          <link rel="alternate nofollow" type="text/html" href="page">
          <link rel="alternate nofollow" href="missing-type">
          <link rel="alternate nofollow" type="application/rss+xml">
          <link rel="alternate nofollow" type="application/rss+xml" href="">
          <link rel="alternate nofollow" type="application/rss+xml" href=" \t ">
          <link rel="alternate nofollow" type="application/rss+xml" title="RSS" href="feed.rss">
          <link rel="nofollow ALTERNATE" type="application/atom+xml" href="feed.atom">
          <link rel="AlTeRnAtE nofollow" type="application/json" href="feed.json">
        </head></html>
      HTML
    end

    it "keeps supported feeds in document order, skips invalid feeds and resolves the base URL" do
      expect(page.feeds).to eq([
        { title: 'RSS', href: 'https://feeds.example.com/blog/feed.rss', type: 'application/rss+xml' },
        { title: nil, href: 'https://feeds.example.com/blog/feed.atom', type: 'application/atom+xml' },
        { title: nil, href: 'https://feeds.example.com/blog/feed.json', type: 'application/json' }
      ])
    end
  end

end
