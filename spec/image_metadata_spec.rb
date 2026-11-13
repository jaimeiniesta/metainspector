require 'spec_helper'

RSpec.describe 'image metadata' do
  let(:url) { 'https://example.com/image.png' }
  let(:png) { "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [37, 29].pack('NN') + "\x08\x02\x00\x00\x00".b }
  let(:html) { %(<img src="#{url}" width="10" height="20">) }

  it 'returns metadata without changing the existing size tuples' do
    stub_request(:get, url).to_return(body: png, headers: { 'Content-Length' => '1234' })
    page = MetaInspector.new('https://example.com/', document: html)
    expect(page.images.with_details).to eq([{ url: url, width: 10, height: 20, type: :png, file_size: 1234 }])
    expect(page.images.with_size).to eq([[url, 10, 20]])
    expect(a_request(:get, url)).to have_been_made.once
  end

  it 'uses the total from a partial response rather than its content length' do
    stub_request(:get, url).to_return(status: 206, body: png,
      headers: { 'Content-Length' => png.bytesize.to_s, 'Content-Range' => 'bytes 0-28/5000' })
    page = MetaInspector.new('https://example.com/', document: %(<img src="#{url}">))
    expect(page.images.with_details).to eq([{ url: url, width: 37, height: 29, type: :png, file_size: 5000 }])
  end

  it 'returns nil metadata for failed and disabled downloads' do
    stub_request(:get, url).to_timeout
    page = MetaInspector.new('https://example.com/', document: html)
    expect(page.images.with_details.first).to eq(url: url, width: 10, height: 20, type: nil, file_size: nil)
    disabled = MetaInspector.new('https://example.com/', document: html, download_images: false)
    expect(disabled.images.with_details.first).to eq(url: url, width: 10, height: 20, type: nil, file_size: nil)
    expect(a_request(:get, url)).to have_been_made.once
  end

  it 'preserves each HTML dimension when the other is missing' do
    stub_request(:get, url).to_return(body: png)
    page = MetaInspector.new('https://example.com/', document: %(<img src="#{url}" width="640">))
    expect(page.images.with_details.first).to include(width: 640, height: 29)
    disabled = MetaInspector.new('https://example.com/', download_images: false,
      document: %(<img src="#{url}" height="480">))
    expect(disabled.images.with_details.first).to include(width: 0, height: 480)
  end

  it 'counts the bytes of a complete response without a reported length' do
    stub_request(:get, url).to_return(body: png)
    page = MetaInspector.new('https://example.com/', document: html)
    expect(page.images.with_details.first[:file_size]).to eq(png.bytesize)
  end

  it 'does not treat a stopped download as a complete file' do
    stub_request(:get, url).to_return(body: png + ('x' * (256 * 1024)))
    page = MetaInspector.new('https://example.com/', document: html)
    expect(page.images.with_details.first[:file_size]).to be_nil
  end

  it 'does not mistake a partial or compressed response length for the file size' do
    stub_request(:get, url).to_return(status: 206, body: png, headers: { 'Content-Length' => '29' })
    page = MetaInspector.new('https://example.com/', document: html)
    expect(page.images.with_details.first).to include(type: :png, file_size: nil)
  end

  it 'respects the download limit and sorts by area' do
    other = 'https://example.com/other.png'
    stub_request(:get, url).to_return(body: png)
    page = MetaInspector.new('https://example.com/', max_image_downloads: 1,
      document: %(<img src="#{url}"><img src="#{url}"><img src="#{other}" width="100" height="100">))
    expect(page.images.with_details).to eq([
      { url: other, width: 100, height: 100, type: nil, file_size: nil },
      { url: url, width: 37, height: 29, type: :png, file_size: png.bytesize }
    ])
    expect(page.images.with_details.length).to eq(2)
    expect(a_request(:get, url)).to have_been_made.once
    expect(a_request(:get, other)).not_to have_been_made
  end

  it 'propagates URL policy failures' do
    page = MetaInspector.new('https://example.com/', document: html, url_filter: ->(_) { false })
    expect { page.images.with_details }.to raise_error(MetaInspector::RequestError)
  end

  it 'includes responsive image candidates without fetching non-HTTP sources' do
    stub_request(:get, url).to_return(body: png)
    html = %(<picture><source srcset="#{url} 2x, data:image/png;base64,AAAA 1x"></picture>)
    page = MetaInspector.new('https://example.com/', document: html)
    expect(page.images.with_details).to include(include(url: url, type: :png, file_size: png.bytesize))
    expect(page.images.with_details).to include(include(url: 'data:image/png;base64,AAAA', type: nil, file_size: nil))
  end
end
