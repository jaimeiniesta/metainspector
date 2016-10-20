require 'spec_helper'

describe MetaInspector::Sanitizer do
  let(:sanitizer) { MetaInspector::Sanitizer.new }

  describe '#trim_whitespace' do
    it 'trims whitespace at start and end' do
      expect(sanitizer.trim_whitespace("\n\t \r Hello World    \n   ")).to eq("Hello World")
    end
    it 'collapses multiple whitespace in between' do
      expect(sanitizer.trim_whitespace("Hello   \n\t \r World")).to eq("Hello World")
    end
  end

  describe '#unescape_html_entities' do
    it 'unescapes html entities' do
      expect(sanitizer.unescape_html_entities('&amp;&ndash;&euro;')).to eq('&–€')
    end
  end

  describe '#scrub_html_tags' do
    it 'removes dangerous tags' do
      expect(sanitizer.scrub_html_tags('Hello <script>alert("Virus!")</script> World')).to eq('Hello  World')
    end
    it 'removes unknown tags' do
      expect(sanitizer.scrub_html_tags('Hello <supertag>fabulous</supertag> World')).to eq('Hello  World')
    end
    it 'replaces safe tags' do
      expect(sanitizer.scrub_html_tags('Hello <strong>fabulous</strong> World')).to eq('Hello fabulous World')
    end
  end

  describe '#sanitize' do
    let(:raw_html) { %Q{<meta name="test" content="value" />\n<p>This <strong>is</strong>\n allowed &amp; valid.</p> <amp-img src=sample.jpg width=300 height=300>Gets removed</amp-img>\n\t} }
    let(:sanitized_string) { %Q{This is allowed & valid.} }

    it 'applies all the above sanitizing steps to a string' do
      expect(sanitizer.sanitize(raw_html)).to eq sanitized_string
    end

    it 'applies all the above sanitizing steps to a nokogiri node' do
      expect(sanitizer.sanitize(Nokogiri.HTML(raw_html))).to eq sanitized_string
    end
  end
end
