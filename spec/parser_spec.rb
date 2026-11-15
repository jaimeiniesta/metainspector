require 'spec_helper'

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
end
