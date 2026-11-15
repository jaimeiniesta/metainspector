require 'spec_helper'
require 'base64'

RSpec.describe 'inline images' do
  let(:png) { "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [37, 29].pack('NN') + "\x08\x02\x00\x00\x00".b }
  let(:data_url) { "data:image/png;base64,#{Base64.strict_encode64(png)}" }
  let(:encoded_url) { 'data:image/png,' + png.bytes.map { |byte| format('%%%02X', byte) }.join }

  it 'returns PNG type and decoded byte size for base64 and percent-encoded images without spending the download budget' do
    html = %(<img src="#{data_url}"><img src="#{encoded_url}"><img src="ftp://example.com/a"><img src="/good">)
    stub_request(:get, 'http://example.com/good').to_return(body: png)
    page = MetaInspector.new('http://example.com/', document: html, max_image_downloads: 1, fetch_all_image_meta: true, inline_image_data: true)
    expect(page.images.with_metadata.map { |entry| entry[:valid] }).to eq([true, true, false, true])
    expect(page.images.with_details).to include({ url: data_url, width: 37, height: 29, type: :png, file_size: png.bytesize },
                                               { url: encoded_url, width: 37, height: 29, type: :png, file_size: png.bytesize })
    expect(a_request(:get, 'http://example.com/good')).to have_been_made.once
  end

  it 'returns unknown details for invalid data and unsupported schemes, and rejects them when validating' do
    html = '<img src="data:image/png;base64,!!!!"><img src="file:///bad">'
    page = MetaInspector.new('http://example.com/', document: html)
    expect(page.images.with_size.map { |_, w, h| [w, h] }).to eq([[0, 0], [0, 0]])
    expect(page.images.with_details.map { |item| [item[:type], item[:file_size]] }).to eq([[nil, nil], [nil, nil]])
    validating = MetaInspector.new('http://example.com/', document: html, download_image_options: { reject_invalid_images: true })
    expect(validating.images.to_a).to be_empty
  end

  it 'hides payloads in every image result while retaining distinct candidates' do
    second = 'data:image/png;base64,' + Base64.strict_encode64(png.sub([37, 29].pack('NN'), [2, 3].pack('NN')))
    html = %(<meta property="og:image" content="#{data_url}"><link rel="icon" href="#{data_url}"><img src="#{data_url}"><img src="#{second}"><img src="/photo" width="800" height="600">)
    page = MetaInspector.new('http://example.com/', document: html, fetch_all_image_meta: true)
    stub_request(:get, 'http://example.com/photo').to_return(body: png)
    expect(page.images.to_a).to eq(['data:image/png;base64', 'data:image/png;base64', 'http://example.com/photo'])
    expect(page.images[0]).to eq('data:image/png;base64')
    expect(page.images.with_size).to eq([['http://example.com/photo', 800, 600], ['data:image/png;base64', 37, 29], ['data:image/png;base64', 2, 3]])
    expect(page.images.with_details.map { |item| item[:url] }).to eq(['http://example.com/photo', 'data:image/png;base64', 'data:image/png;base64'])
    expect(page.images.with_metadata.map { |item| item[:url] }).to eq(page.images.to_a)
    expect(page.images.owner_suggested).to eq('data:image/png;base64')
    expect(page.images.favicon).to eq('data:image/png;base64')
    expect(page.images.best).to eq('http://example.com/photo')
    expect(page.images.largest).to eq('http://example.com/photo')
    expect(page.meta['og:image']).to eq(data_url)
  end

  it 'returns and ranks full data URLs when opted in' do
    html = %(<meta property="og:image" content="#{data_url}"><img src="#{data_url}">)
    page = MetaInspector.new('http://example.com/', document: html, inline_image_data: true)
    expect(page.images.to_a).to eq([data_url])
    expect(page.images.with_size).to eq([[data_url, 37, 29]])
    expect(page.images.largest).to eq(data_url)
    expect(page.images.best).to eq(data_url)
  end

  it 'decodes local images after the HTTP download budget is exhausted' do
    page = MetaInspector.new('http://example.com/', document: %(<img src="#{data_url}">),
      max_image_downloads: 0, fetch_all_image_meta: true, inline_image_data: true)
    expect(page.images.with_metadata).to eq([{ url: data_url, valid: true }])
    expect(page.images.with_details.first).to include(width: 37, height: 29, type: :png, file_size: png.bytesize)
  end

  it 'skips inline suggested images for best and keeps raw metadata in to_hash' do
    html = %(<meta property="og:image" content="#{data_url}"><meta name="twitter:image" content="/photo"><img src="#{data_url}">)
    stub_request(:get, 'http://example.com/page').to_return(body: html, headers: { 'Content-Type' => 'text/html' })
    page = MetaInspector.new('http://example.com/page')
    expect(page.images.best).to eq('http://example.com/photo')
    expect(page.to_hash['images']).to eq(['data:image/png;base64'])
    expect(page.meta['og:image']).to eq(data_url)
  end

  it 'returns no largest or best image when all images are inline placeholders' do
    page = MetaInspector.new('http://example.com/', document: %(<img src="#{data_url}">))
    expect(page.images.largest).to be_nil
    expect(page.images.best).to be_nil
  end
end
