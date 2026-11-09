require 'spec_helper'

describe MetaInspector do
  describe '#iframes' do
    def page_with(html, url = 'http://example.com/')
      MetaInspector.new(url, document: html)
    end

    describe '#attributes' do
      it 'returns every attribute of every iframe' do
        html = '<iframe src="/embed/1" width="560" height="315" title="Intro" ' \
               'allowfullscreen loading="lazy" data-test="player"></iframe>'

        expect(page_with(html).iframes.attributes).to eq([{
          src: 'http://example.com/embed/1',
          width: '560',
          height: '315',
          title: 'Intro',
          allowfullscreen: '',
          loading: 'lazy',
          "data-test": 'player'
        }])
      end

      it 'keeps srcdoc content decoded' do
        html = '<iframe srcdoc="&lt;p&gt;Hi&lt;/p&gt;" title="Inline"></iframe>'

        expect(page_with(html).iframes.attributes)
          .to eq([{ srcdoc: '<p>Hi</p>', title: 'Inline' }])
      end

      it 'returns an entry for every iframe, in document order' do
        html = '<iframe src="/embed/1"></iframe><iframe title="No src"></iframe>'

        expect(page_with(html).iframes.attributes).to eq([
          { src: 'http://example.com/embed/1' },
          { title: 'No src' }
        ])
      end

      it 'resolves protocol-relative sources using the document scheme' do
        html = '<iframe src="//player.example.com/embed/1" width="640"></iframe>'

        expect(page_with(html, 'https://example.com/').iframes.attributes)
          .to eq([{ src: 'https://player.example.com/embed/1', width: '640' }])
      end

      it 'resolves relative sources against the base href' do
        html = '<base href="/assets/"><iframe src="embed/1"></iframe>'

        expect(page_with(html, 'http://example.com/articles/page').iframes.attributes)
          .to eq([{ src: 'http://example.com/assets/embed/1' }])
      end

      it 'preserves query strings without normalizing them' do
        html = '<iframe src="/embed?b=2&amp;a=1"></iframe>'

        expect(page_with(html).iframes.attributes)
          .to eq([{ src: 'http://example.com/embed?b=2&a=1' }])
      end

      it 'keeps blank sources as-is instead of resolving them to the base URL' do
        html = '<iframe src=""></iframe><iframe src="   "></iframe>'

        expect(page_with(html).iframes.attributes)
          .to eq([{ src: '' }, { src: '   ' }])
      end

      it 'returns an empty array when the page has no iframes' do
        expect(page_with('<p>No iframes here</p>').iframes.attributes).to eq([])
      end
    end

    describe '#src' do
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
    end

    it 'behaves as an enumerable collection of attribute hashes' do
      html = '<iframe src="/embed/1"></iframe><iframe src="/embed/2" title="Two"></iframe>'
      iframes = page_with(html).iframes

      expect(iframes.to_a).to eq([
        { src: 'http://example.com/embed/1' },
        { src: 'http://example.com/embed/2', title: 'Two' }
      ])
      expect(iframes.size).to eq(2)
      expect(iframes.length).to eq(2)
      expect(iframes.first).to eq(src: 'http://example.com/embed/1')
      expect(iframes.last).to eq(src: 'http://example.com/embed/2', title: 'Two')
      expect(iframes[1]).to eq(src: 'http://example.com/embed/2', title: 'Two')
    end

    it 'includes the iframe attributes in to_hash' do
      stub_request(:get, 'http://example.com/').to_return(
        body: '<iframe src="/embed/1" width="560"></iframe>',
        headers: { 'Content-Type' => 'text/html' }
      )

      expect(MetaInspector.new('http://example.com/').to_hash['iframes'])
        .to eq([{ src: 'http://example.com/embed/1', width: '560' }])
    end
  end
end
