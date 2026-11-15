require 'spec_helper'

RSpec.describe 'image validity' do
  let(:png) { "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [37, 29].pack('NN') + "\x08\x02\x00\x00\x00".b }
  let(:options) { { download_image_options: { reject_invalid_images: true } } }

  before do
    stub_request(:get, 'http://example.com/missing').to_return(status: 404)
    stub_request(:get, 'http://example.com/not-image').to_return(body: 'not an image')
    stub_request(:get, 'http://example.com/failure').to_timeout
    stub_request(:get, 'http://example.com/good').to_return(body: png)
  end

  it 'skips invalid suggested images and falls back to a valid suggested image' do
    html = '<meta property="og:image" content="/missing"><meta name="twitter:image" content="/good">'
    page = MetaInspector.new('http://example.com/', **options, document: html)
    expect(page.images.owner_suggested).to eq('http://example.com/good')
    expect(page.images.best).to eq('http://example.com/good')
    expect(a_request(:get, 'http://example.com/good')).to have_been_made.once
  end

  it 'filters invalid images even when HTML dimensions are present and falls back to a valid image' do
    html = '<meta property="og:image" content="/missing"><img src="/not-image" width="100" height="100"><img src="/failure"><img src="/good" width="10" height="10">'
    page = MetaInspector.new('http://example.com/', **options, document: html)
    expect(page.images.to_a).to eq(['http://example.com/good'])
    expect(page.images.with_size).to eq([['http://example.com/good', 10, 10]])
    expect(page.images.best).to eq('http://example.com/good')
    expect(a_request(:get, 'http://example.com/good')).to have_been_made.once
  end

  it 'exposes validity for attempted images and nil for images beyond the limit' do
    html = '<img src="/missing"><img src="/good" width="10" height="10"><img src="/not-image">'
    page = MetaInspector.new('http://example.com/', document: html, fetch_all_image_meta: true, max_image_downloads: 2)
    expect(page.images.with_metadata).to eq([
      { url: 'http://example.com/missing', valid: false },
      { url: 'http://example.com/good', valid: true },
      { url: 'http://example.com/not-image', valid: nil }
    ])
  end

  it 'does not reject or download unverified images when downloads are disabled or exhausted' do
    html = '<meta property="og:image" content="/missing"><img src="/not-image" width="10" height="10">'
    [ { download_images: false }, { max_image_downloads: 0 } ].each do |limits|
      page = MetaInspector.new('http://example.com/', **options, **limits, document: html)
      expect(page.images.best).to eq('http://example.com/missing')
      expect(page.images.to_a).to eq(['http://example.com/not-image'])
      expect(page.images.with_details).to eq([
        { url: 'http://example.com/not-image', width: 10, height: 10, type: nil, file_size: nil }
      ])
    end
    expect(a_request(:get, 'http://example.com/missing')).not_to have_been_made
  end

  it 'preserves default suggested-image and collection behavior without downloading' do
    html = '<meta property="og:image" content="/missing"><img src="/not-image" width="10" height="10">'
    page = MetaInspector.new('http://example.com/', document: html)
    expect(page.images.best).to eq('http://example.com/missing')
    expect(page.images.to_a).to eq(['http://example.com/not-image'])
    expect(a_request(:get, 'http://example.com/missing')).not_to have_been_made
    expect(a_request(:get, 'http://example.com/not-image')).not_to have_been_made
  end

  it 'returns nil when all suggested and collection images are invalid' do
    html = '<meta property="og:image" content="/missing"><img src="/not-image" width="10" height="10">'
    page = MetaInspector.new('http://example.com/', **options, document: html)
    expect(page.images.owner_suggested).to be_nil
    expect(page.images.best).to be_nil
    expect(page.images.to_a).to be_empty
  end

  it 'treats unsupported image URL schemes as invalid' do
    html = '<meta property="og:image" content="data:image/png;base64,AAAA"><img src="ftp://example.com/image.png"><img src="/good">'
    page = MetaInspector.new('http://example.com/', **options, document: html, fetch_all_image_meta: true)
    expect(page.images.best).to eq('http://example.com/good')
    expect(page.images.to_a).to eq(['http://example.com/good'])
    expect(page.images.with_metadata.first).to eq(url: 'ftp://example.com/image.png', valid: false)
  end

  it 'raises for redirects to unsupported schemes during validation' do
    stub_request(:get, 'http://example.com/redirect').to_return(status: 302, headers: { 'Location' => 'ftp://example.com/image.png' })
    page = MetaInspector.new('http://example.com/', **options, document: '<img src="/redirect">')
    expect { page.images.to_a }.to raise_error(MetaInspector::URLPolicy::InvalidURL)
  end

  it 'propagates errors from the URL filter during validation' do
    error = MetaInspector::RequestError.new('filter failure')
    page = MetaInspector.new('http://example.com/', **options, document: '<img src="/good">',
      url_filter: ->(_) { raise error })
    expect { page.images.to_a }.to raise_error { |raised| expect(raised).to equal(error) }
  end

  it 'propagates errors raised by the redirect callback during validation' do
    stub_request(:get, 'http://example.com/redirect').to_return(status: 302, headers: { 'Location' => '/good' })
    [MetaInspector::RequestError, MetaInspector::URLPolicy::InvalidURL, Faraday::ConnectionFailed].each do |error_class|
      error = error_class.new('callback failure')
      callback = ->(_, _) { raise error }
      page = MetaInspector.new('http://example.com/', **options, document: '<img src="/redirect">',
        faraday_options: { redirect: { callback: callback } })
      expect { page.images.to_a }.to raise_error { |raised| expect(raised).to equal(error) }
    end
  end

  it 'raises for unsupported redirects in metadata-only mode' do
    stub_request(:get, 'http://example.com/redirect').to_return(status: 302, headers: { 'Location' => 'ftp://example.com/image.png' })
    page = MetaInspector.new('http://example.com/', document: '<img src="/redirect">', fetch_all_image_meta: true)
    expect { page.images.with_metadata }.to raise_error(MetaInspector::URLPolicy::InvalidURL)
  end

  it 'preserves default behavior for redirects to unsupported schemes' do
    stub_request(:get, 'http://example.com/redirect').to_return(status: 302, headers: { 'Location' => 'ftp://example.com/image.png' })
    page = MetaInspector.new('http://example.com/', document: '<img src="/redirect">')
    expect { page.images.with_size }.to raise_error(MetaInspector::RequestError, /HTTP or HTTPS/)
  end

  describe 'image details' do
    it 'omits images that failed validation instead of raising for unsupported URLs' do
      html = '<img src="data:image/png;base64,AAAA"><img src="ftp://example.com/image.png"><img src="/missing">' \
             '<img src="/good" width="10" height="10">'
      page = MetaInspector.new('http://example.com/', **options, document: html)
      expect(page.images.with_details).to eq([
        { url: 'http://example.com/good', width: 10, height: 10, type: :png, file_size: png.bytesize }
      ])
    end

    it 'reuses validation lookups instead of downloading images again' do
      page = MetaInspector.new('http://example.com/', **options, document: '<img src="/good">')
      expect(page.images.to_a).to eq(['http://example.com/good'])
      expect(page.images.with_details).to eq([
        { url: 'http://example.com/good', width: 37, height: 29, type: :png, file_size: png.bytesize }
      ])
      expect(a_request(:get, 'http://example.com/good')).to have_been_made.once
    end

    it 'shares the validation budget and keeps unchecked images without metadata' do
      html = '<meta property="og:image" content="/missing"><img src="/good" width="10" height="10">'
      page = MetaInspector.new('http://example.com/', **options, document: html, max_image_downloads: 1)
      expect(page.images.owner_suggested).to be_nil
      expect(page.images.with_details).to eq([
        { url: 'http://example.com/good', width: 10, height: 10, type: nil, file_size: nil }
      ])
      expect(a_request(:get, 'http://example.com/good')).not_to have_been_made
    end

    it 'does not spend the budget on unsupported URLs, which need no request' do
      html = '<picture><source srcset="data:image/png;base64,AAAA 1x"></picture><img src="/good">'
      page = MetaInspector.new('http://example.com/', **options, document: html, max_image_downloads: 1)
      expect(page.images.with_details).to eq([
        { url: 'http://example.com/good', width: 37, height: 29, type: :png, file_size: png.bytesize }
      ])
    end

    it 'propagates URL filter rejections' do
      page = MetaInspector.new('http://example.com/', **options, document: '<img src="/good">',
        url_filter: ->(_) { false })
      expect { page.images.with_details }.to raise_error(MetaInspector::RequestError, /url_filter/)
    end

    it 'propagates invalid URL errors raised by the redirect callback' do
      stub_request(:get, 'http://example.com/redirect').to_return(status: 302, headers: { 'Location' => '/good' })
      error = MetaInspector::URLPolicy::InvalidURL.new('callback failure')
      page = MetaInspector.new('http://example.com/', **options, document: '<img src="/redirect">',
        faraday_options: { redirect: { callback: ->(_, _) { raise error } } })
      expect { page.images.with_details }.to raise_error { |raised| expect(raised).to equal(error) }
    end

    it 'keeps unsupported URLs and failed lookups with unknown metadata in metadata-only mode' do
      html = '<img src="data:image/png;base64,AAAA"><img src="/missing" width="5" height="5"><img src="/good">'
      page = MetaInspector.new('http://example.com/', document: html, fetch_all_image_meta: true)
      expect(page.images.with_details).to eq([
        { url: 'http://example.com/good', width: 37, height: 29, type: :png, file_size: png.bytesize },
        { url: 'http://example.com/missing', width: 5, height: 5, type: nil, file_size: nil },
        { url: 'data:image/png;base64', width: 0, height: 0, type: nil, file_size: nil }
      ])
    end

    it 'treats Unicode image URLs that cannot be normalized as invalid' do
      html = %(<img src="http://%C3/ñ.png"><img src="/good" width="10" height="10">)
      page = MetaInspector.new('http://example.com/', **options, document: html)
      expect(page.images.to_a).to eq(['http://example.com/good'])
      expect(page.images.with_details).to eq([
        { url: 'http://example.com/good', width: 10, height: 10, type: :png, file_size: png.bytesize }
      ])
    end

    it 'validates Unicode image URLs in their encoded form, preserving the original URL' do
      original = "http://example.com/image\u202fname.png"
      stub_request(:get, 'http://example.com/image%E2%80%AFname.png').to_return(body: png)
      page = MetaInspector.new('http://example.com/', **options, document: %(<img src="#{original}">))
      expect(page.images.to_a).to eq([original])
      expect(page.images.with_details).to eq([
        { url: original, width: 37, height: 29, type: :png, file_size: png.bytesize }
      ])
    end
  end
end
