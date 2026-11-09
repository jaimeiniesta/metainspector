require 'spec_helper'

describe MetaInspector do
  describe '#iframes' do
    def page_with(html, url = 'http://example.com/')
      MetaInspector.new(url, document: html)
    end

    it 'returns the source of every iframe as an absolute URL' do
      html = '<iframe src="https://player.example.com/embed/1"></iframe>' \
             '<iframe src="/embed/2"></iframe>' \
             '<iframe src="embed/3"></iframe>'

      expect(page_with(html).iframes.src).to eq([
        'https://player.example.com/embed/1',
        'http://example.com/embed/2',
        'http://example.com/embed/3'
      ])
    end

    it 'resolves protocol-relative sources using the document scheme' do
      html = '<iframe src="//player.example.com/embed/1"></iframe>'

      expect(page_with(html, 'https://example.com/').iframes.src)
        .to eq(['https://player.example.com/embed/1'])
    end

    it 'resolves relative sources against the base href' do
      html = '<base href="/assets/"><iframe src="embed/1"></iframe>'

      expect(page_with(html, 'http://example.com/articles/page').iframes.src)
        .to eq(['http://example.com/assets/embed/1'])
    end

    it 'preserves query strings without normalizing them' do
      html = '<iframe src="/embed?b=2&amp;a=1"></iframe>'

      expect(page_with(html).iframes.src).to eq(['http://example.com/embed?b=2&a=1'])
    end

    it 'ignores iframes without a source and blank sources' do
      html = '<iframe></iframe><iframe src=""></iframe><iframe src="   "></iframe>' \
             '<iframe src="/embed/1"></iframe>'

      expect(page_with(html).iframes.src).to eq(['http://example.com/embed/1'])
    end

    it 'deduplicates repeated sources' do
      html = '<iframe src="/embed/1"></iframe><iframe src="/embed/1"></iframe>'

      expect(page_with(html).iframes.src).to eq(['http://example.com/embed/1'])
    end

    it 'returns an empty array when the page has no iframes' do
      expect(page_with('<p>No iframes here</p>').iframes.src).to eq([])
    end

    it 'behaves as an enumerable collection' do
      html = '<iframe src="/embed/1"></iframe><iframe src="/embed/2"></iframe>'
      iframes = page_with(html).iframes

      expect(iframes.to_a).to eq(['http://example.com/embed/1', 'http://example.com/embed/2'])
      expect(iframes.size).to eq(2)
      expect(iframes.length).to eq(2)
      expect(iframes.first).to eq('http://example.com/embed/1')
      expect(iframes.last).to eq('http://example.com/embed/2')
      expect(iframes[1]).to eq('http://example.com/embed/2')
    end

    it 'includes the iframe sources in to_hash' do
      stub_request(:get, 'http://example.com/').to_return(
        body: '<iframe src="/embed/1"></iframe>',
        headers: { 'Content-Type' => 'text/html' }
      )

      expect(MetaInspector.new('http://example.com/').to_hash['iframes'])
        .to eq(['http://example.com/embed/1'])
    end
  end
end
