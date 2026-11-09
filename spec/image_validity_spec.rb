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
end
