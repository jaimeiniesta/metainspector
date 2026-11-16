require 'spec_helper'
require 'zlib'

RSpec.describe 'compressed page encoding' do
  let(:url) { 'https://encoding.example/page' }
  let(:title) { 'Café – £5' }
  let(:description) { 'Gonçalves – café' }
  let(:html) do
    %(<html><head><title>#{title}</title>) +
      %(<meta name="description" content="#{description}"></head></html>)
  end

  %w[gzip deflate].each do |compression|
    context "with #{compression} responses" do
      %w[UTF-8 Windows-1252].each do |charset|
        context "declaring #{charset} only in Content-Type" do
          before do
            body = html.encode(charset)
            compressed = compression == 'gzip' ? Zlib.gzip(body) : Zlib::Deflate.deflate(body)
            stub_request(:get, url).to_return(body: compressed, headers: {
              'Content-Type' => "text/html; charset=#{charset}",
              'Content-Encoding' => compression
            })
          end

          it 'preserves the charset when the server compresses despite the default headers' do
            page = MetaInspector.new(url)

            expect(page.title).to eq(title)
            expect(page.description).to eq(description)
            expect(page.to_s.encoding).to eq(Encoding.find(charset))
            expect(a_request(:get, url).with(headers: { 'Accept-Encoding' => 'identity' })).to have_been_made.once
          end

          it 'preserves the charset with a custom User-Agent' do
            page = MetaInspector.new(url, headers: { 'User-Agent' => 'MyApp/1.0' })

            expect(page.title).to eq(title)
            expect(page.description).to eq(description)
            expect(page.to_s.encoding).to eq(Encoding.find(charset))
            expect(a_request(:get, url).with(headers: { 'User-Agent' => 'MyApp/1.0' })).to have_been_made.once
          end
        end
      end
    end
  end
end

RSpec.describe 'non-ASCII-compatible page encoding' do
  let(:url) { 'https://encoding.example/page' }
  let(:html) do
    "<html><head><title>Hel\u0000lo 日本語</title></head>" \
      "<body><a href=\"/a\u0000fter\">after</a></body></html>"
  end

  %w[UTF-16LE UTF-16BE UTF-16 UTF-32LE UTF-32BE UTF-32 ISO-2022-JP].each do |charset|
    it "parses #{charset} responses and removes NUL characters without changing the raw body" do
      body = html.encode(charset).b
      stub_request(:get, url).to_return(body: body, headers: {
        'Content-Type' => "text/html; charset=#{charset}"
      })

      page = MetaInspector.new(url)

      expect(page.title).to eq('Hello 日本語')
      expect(page.links.raw).to eq(['/after'])
      expect(page.to_s.encoding).to eq(Encoding::UTF_8)
      expect(page.to_s).not_to include("\u0000")
      expect(page.response.body.b).to eq(body)
      expect(page.response.body.encoding).to eq(Encoding.find(charset))
    end
  end

  it 'normalizes a forced UTF-16LE encoding before removing NUL characters' do
    stub_request(:get, url).to_return(body: html.encode('UTF-16LE').b, headers: {
      'Content-Type' => 'text/html'
    })

    page = MetaInspector.new(url, encoding: 'UTF-16LE')

    expect(page.title).to eq('Hello 日本語')
    expect(page.links.raw).to eq(['/after'])
  end

  it 'normalizes a gzip-compressed UTF-16LE response after decompression' do
    body = html.encode('UTF-16LE').b
    stub_request(:get, url).to_return(body: Zlib.gzip(body), headers: {
      'Content-Type' => 'text/html; charset=UTF-16LE', 'Content-Encoding' => 'gzip'
    })

    page = MetaInspector.new(url)

    expect(page.title).to eq('Hello 日本語')
    expect(page.links.raw).to eq(['/after'])
    expect(page.response.body.b).to eq(body)
  end

  it 'wraps invalid UTF-16LE bytes in RequestError' do
    body = html.encode('UTF-16LE').b + "\x00".b
    stub_request(:get, url).to_return(body: body, headers: {
      'Content-Type' => 'text/html; charset=UTF-16LE'
    })

    expect { MetaInspector.new(url) }.to raise_error(MetaInspector::RequestError) { |error|
      expect(error.cause).to be_a(Encoding::InvalidByteSequenceError)
      expect(error.message).to eq(error.cause.message)
    }
  end

  it 'wraps unsupported UTF-7 conversion in RequestError' do
    stub_request(:get, url).to_return(body: '<title>Hello</title>', headers: {
      'Content-Type' => 'text/html; charset=UTF-7'
    })

    expect { MetaInspector.new(url) }.to raise_error(MetaInspector::RequestError) { |error|
      expect(error.cause).to be_a(Encoding::ConverterNotFoundError)
      expect(error.message).to eq(error.cause.message)
    }
  end
end
