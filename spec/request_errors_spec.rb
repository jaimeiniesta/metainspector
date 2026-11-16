require 'spec_helper'

RSpec.describe 'request error handling' do
  let(:url) { 'https://errors.example/page' }

  %w[gzip deflate].each do |compression|
    it "wraps malformed #{compression} responses in RequestError" do
      stub_request(:get, url).to_return(body: 'not compressed', headers: {
        'Content-Type' => 'text/html', 'Content-Encoding' => compression
      })

      expect { MetaInspector.new(url) }.to raise_error(MetaInspector::RequestError) { |error|
        expect(error.cause).to be_a(Zlib::Error)
        expect(error.message).to eq(error.cause.message)
      }
    end
  end

  it 'wraps malformed mailto page URLs in RequestError' do
    expect { MetaInspector.new('mailto:') }.to raise_error(MetaInspector::RequestError) { |error|
      expect(error.cause).to be_a(URI::InvalidComponentError)
    }
  end

  [:head, :get].each do |method|
    it "wraps malformed mailto destinations in #{method} redirects in RequestError" do
      stub_request(method, url).to_return(status: 302, headers: { 'Location' => 'mailto:' })

      expect { MetaInspector.new(url, head_first: method == :head) }
        .to raise_error(MetaInspector::RequestError) { |error|
          expect(error.cause).to be_a(URI::InvalidComponentError)
        }
    end
  end

  it 'reports malformed mailto images with unknown dimensions and no best image' do
    page = MetaInspector.new(url, document: '<img src="mailto:">')

    expect(page.images.with_size).to eq([['mailto:', 0, 0]])
    expect(page.images.best).to be_nil
  end

  it 'rejects malformed mailto destinations in image redirects with RequestError' do
    stub_request(:get, 'https://errors.example/image').to_return(status: 302, headers: { 'Location' => 'mailto:' })
    page = MetaInspector.new(url, document: '<img src="/image">')

    expect { page.images.with_size }.to raise_error(MetaInspector::RequestError) { |error|
      expect(error.cause).to be_a(URI::InvalidComponentError)
    }
  end
end
