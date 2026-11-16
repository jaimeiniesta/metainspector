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
