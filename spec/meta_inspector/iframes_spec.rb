require 'spec_helper'

describe MetaInspector do
  def page_with_iframes(html, url = 'https://example.com/articles/page')
    MetaInspector.new(url, document: html)
  end

  it 'returns an array of original iframe attributes in document order' do
    page = page_with_iframes('<iframe src=" /embed " title="First" allowfullscreen data-id="1"></iframe>' \
                             '<iframe src=" /embed "></iframe><iframe srcdoc="&lt;p&gt;Hi&lt;/p&gt;"></iframe>')

    expect(page.iframes).to eq([
      { src: ' /embed ', title: 'First', allowfullscreen: '', 'data-id': '1' },
      { src: ' /embed ' },
      { srcdoc: '<p>Hi</p>' }
    ])
    expect(page.iframes).to be_an(Array)
  end

  it 'resolves sources against the base URL, preserving positions and duplicates' do
    html = '<base href="/assets/"><iframe src="  embed?b=2&amp;a=1  "></iframe>' \
           '<iframe src="//player.example.com/video"></iframe><iframe src="embed?b=2&amp;a=1"></iframe>' \
           '<iframe></iframe><iframe src=" "></iframe><iframe src="http://a:bad/"></iframe>'
    page = page_with_iframes(html)

    expect(page.iframe_sources).to eq([
      'https://example.com/assets/embed?b=2&a=1',
      'https://player.example.com/video',
      'https://example.com/assets/embed?b=2&a=1',
      nil, nil, nil
    ])
    expect(page.iframes.last[:src]).to eq('http://a:bad/')
  end

  it 'returns empty arrays when there are no iframes' do
    page = page_with_iframes('<p>No iframes</p>')
    expect(page.iframes).to eq([])
    expect(page.iframe_sources).to eq([])
  end

  it 'includes iframe attributes in to_hash' do
    stub_request(:get, 'http://example.com/').to_return(
      body: '<iframe src="/embed" width="560"></iframe>',
      headers: { 'Content-Type' => 'text/html' }
    )

    expect(MetaInspector.new('http://example.com/').to_hash['iframes'])
      .to eq([{ src: '/embed', width: '560' }])
  end
end
