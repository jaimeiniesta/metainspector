require 'spec_helper'
require 'json'

describe MetaInspector::Parser do
  let(:doc)    { MetaInspector::Document.new('http://pagerankalert.com') }
  let(:parser) { MetaInspector::Parser.new(doc) }

  it 'returns the first feed URL through the deprecated feed method' do
    expect { expect(parser.feed).to eq('http://feeds.feedburner.com/PageRankAlert') }
      .to output(/DEPRECATION.*page\.feed.*6\.0.*page\.feeds/).to_stderr
  end

  it 'returns the favicon URL through the deprecated favicon method' do
    expect { expect(parser.favicon).to eq('http://pagerankalert.com/src/favicon.ico') }
      .to output(/DEPRECATION.*page\.favicon.*6\.0.*page\.images\.favicon/).to_stderr
  end

  it "should have a Nokogiri::HTML::Document as parsed" do
    expect(parser.parsed.class).to eq(Nokogiri::HTML::Document)
  end

  it "should return the document as a string" do
    expect(parser.to_s.class).to eq(String)
  end

  describe 'parser resource limits' do
    let(:deep_html) do
      "<html><body>#{'<div>' * 256}<a href=\"/deep\">deep</a>#{'</div>' * 256}" \
        '<a href="/after">after</a><h1>After</h1></body></html>'
    end

    it 'rejects a passed document truncated by the nesting limit' do
      expect do
        MetaInspector.new('http://example.com', document: deep_html)
      end.to raise_error(MetaInspector::ParserError, /Excessive depth in document/)
    end

    it 'rejects a downloaded document truncated by the nesting limit' do
      stub_request(:get, 'http://example.com/').to_return(
        body: deep_html, headers: { 'Content-Type' => 'text/html' }
      )

      expect do
        MetaInspector.new('http://example.com')
      end.to raise_error(MetaInspector::ParserError, /Excessive depth in document/)
    end

    {
      'text node' => ['<p>', '</p>'],
      'attribute value' => ['<p title="', '">text</p>'],
      'comment' => ['<!--', '-->']
    }.each do |kind, (opening, closing)|
      it "does not silently lose content after an oversized #{kind}" do
        html = "#{opening}#{'x' * 12_000_000}#{closing}<a href=\"/after\">after</a>"

        # Some system libxml2 versions allow oversized attributes and comments.
        if Nokogiri::HTML(html).at_css('a')
          page = MetaInspector.new('http://example.com', document: html)
          expect(page.links.raw).to eq(['/after'])
        else
          expect do
            MetaInspector.new('http://example.com', document: html)
          end.to raise_error(MetaInspector::ParserError, /Resource limit exceeded|huge text node/)
        end
      end
    end

    it 'preserves all links and headings below the nesting limit' do
      html = "<html><body>#{'<div>' * 250}<a href=\"/deep\">deep</a>#{'</div>' * 250}" \
        '<a href="/after">after</a><h1>After</h1></body></html>'
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.links.raw).to eq(['/deep', '/after'])
      expect(page.h1).to eq(['After'])
    end

    it 'continues recovering from ordinary HTML errors' do
      html = '<html><body><unexpected>text</unexpected><a href="/after">after</a></body></html>'
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.parsed.errors).not_to be_empty
      expect(page.links.raw).to eq(['/after'])
    end

    it 'continues recovering from fatal encoding errors that do not truncate the document' do
      html = "<meta charset=\"UTF-8\"><title>caf\xE9</title><a href=\"/after\">after</a>".b
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.parsed.errors.any?(&:fatal?)).to be(true)
      expect(page.links.raw).to eq(['/after'])
    end

    it 'rejects the nonfatal huge-text diagnostic from older system libxml2 versions' do
      parsed = Nokogiri::HTML('<p>truncated</p>')
      error = Nokogiri::XML::SyntaxError.new('xmlSAX2Characters: huge text node')
      allow(error).to receive(:level).and_return(2)
      parsed.errors << error
      allow(Nokogiri).to receive(:HTML).and_return(parsed)

      expect do
        MetaInspector.new('http://example.com', document: '<p>text</p><a href="/after">after</a>')
      end.to raise_error(MetaInspector::ParserError, /huge text node/)
    end
  end

  describe 'invalid bytes in a passed document' do
    let(:html) do
      "<html><head><title>caf\xE9</title></head><body><h1>caf\xE9</h1></body></html>"
    end
    let(:page) { MetaInspector.new('http://example.com', document: html) }

    it 'replaces invalid bytes in the title' do
      expect(page.title).to eq("caf\uFFFD")
    end

    it 'returns a best title without an encoding error' do
      expect(page.best_title).to eq("caf\uFFFD")
    end

    it 'returns headings without an encoding error' do
      expect(page.h1).to eq(["caf\uFFFD"])
    end

    it 'returns serializable metadata without an encoding error' do
      expect(JSON.parse(JSON.generate(page.to_hash))).to include(
        'title' => "caf\uFFFD", 'best_title' => "caf\uFFFD", 'h1' => ["caf\uFFFD"]
      )
    end

    it 'preserves the original document, including when frozen' do
      original = html.dup
      html.freeze

      expect(page.title).to eq("caf\uFFFD")
      expect(page.to_s).to equal(html)
      expect(html).to eq(original)
    end
  end

  describe 'valid bytes in a passed document' do
    it 'preserves valid UTF-8 characters around invalid bytes' do
      html = "<title>Café \xFF 日本語</title>"
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.title).to eq("Café \uFFFD 日本語")
    end

    it 'preserves characters in a valid non-UTF-8 string' do
      html = '<title>Café</title>'.encode('ISO-8859-1')
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.title).to eq('Café')
    end

    it 'allows Nokogiri to detect the charset of a binary string' do
      html = '<meta charset="ISO-8859-1"><title>Café</title>'.encode('ISO-8859-1').b
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.title).to eq('Café')
    end
  end
end
