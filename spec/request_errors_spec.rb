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

  describe 'content encodings that are not decoded' do
    let(:compressed) { "\x1B\x4F\x00\xF8\x8D\x94\x6E\xDE\x44\x55\x86\xD6".b * 50 }

    [['br', 'text/html'], ['zstd', 'text/html; charset=utf-8'], ['gzip, br', 'text/html']].each do |encoding, type|
      it "raises RequestError for Content-Encoding: #{encoding} with #{type}" do
        stub_request(:get, url).to_return(body: compressed, headers: {
          'Content-Type' => type, 'Content-Encoding' => encoding
        })

        expect { MetaInspector.new(url) }
          .to raise_error(MetaInspector::RequestError, "Unsupported Content-Encoding: #{encoding}")
      end
    end

    it 'raises RequestError for non-HTML content too' do
      stub_request(:get, url).to_return(body: compressed, headers: {
        'Content-Type' => 'application/pdf', 'Content-Encoding' => 'br'
      })

      expect { MetaInspector.new(url, allow_non_html_content: true) }
        .to raise_error(MetaInspector::RequestError, 'Unsupported Content-Encoding: br')
    end

    it 'parses an identity-encoded body' do
      stub_request(:get, url).to_return(body: '<title>Hi</title>', headers: {
        'Content-Type' => 'text/html', 'Content-Encoding' => 'Identity'
      })

      expect(MetaInspector.new(url).title).to eq('Hi')
    end

    it 'returns an empty page for an empty body with a Content-Encoding' do
      stub_request(:get, url).to_return(body: '', headers: {
        'Content-Type' => 'text/html', 'Content-Encoding' => 'gzip'
      })

      expect(MetaInspector.new(url).title).to be_nil
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
