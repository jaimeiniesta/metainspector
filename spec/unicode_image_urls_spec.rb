require 'spec_helper'

RSpec.describe 'Unicode image URLs' do
  let(:original) { 'https://example.com/ñ.png' }
  let(:encoded) { 'https://example.com/%C3%B1.png' }
  let(:png) { "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [37, 29].pack('NN') + "\x08\x02\x00\x00\x00".b }

  before { stub_request(:get, encoded).to_return(body: png) }

  ['src', 'srcset'].each do |attribute|
    it "downloads a Unicode #{attribute} image while preserving its original URL" do
      page = MetaInspector.new('https://example.com/', document: %(<img #{attribute}="#{original}">))

      expect(page.images.with_size).to eq([[original, 37, 29]])
      expect(a_request(:get, encoded)).to have_been_made.once
    end
  end

  it 'validates Unicode image and suggested URLs without rejecting them' do
    html = %(<meta property="og:image" content="#{original}"><img src="#{original}">)
    page = MetaInspector.new('https://example.com/', document: html,
      download_image_options: { reject_invalid_images: true }, fetch_all_image_meta: true)

    expect(page.images.owner_suggested).to eq(original)
    expect(page.images.to_a).to eq([original])
    expect(page.images.with_metadata).to eq([{ url: original, valid: true }])
    expect(a_request(:get, encoded)).to have_been_made.once
  end

  it 'applies URL filters to the encoded URL before making a request' do
    seen = []
    page = MetaInspector.new('https://example.com/', document: %(<img srcset="#{original} 1x">),
      fetch_all_image_meta: true, url_filter: ->(uri) { seen << uri.to_s; false })

    expect { page.images.with_metadata }.to raise_error(MetaInspector::RequestError, /blocked by url_filter/)
    expect(seen).to eq([encoded])
    expect(a_request(:get, encoded)).not_to have_been_made
  end

  it 'still applies URL filters to redirects from Unicode image URLs' do
    target = 'https://other.example/image.png'
    stub_request(:get, encoded).to_return(status: 302, headers: { 'Location' => target })
    stub_request(:get, target).to_return(body: png)
    page = MetaInspector.new('https://example.com/', document: %(<img src="#{original}">),
      url_filter: ->(uri) { uri.hostname == 'example.com' })

    expect { page.images.with_size }.to raise_error(MetaInspector::RequestError, /blocked by url_filter/)
    expect(a_request(:get, encoded)).to have_been_made.once
    expect(a_request(:get, target)).not_to have_been_made
  end
end
