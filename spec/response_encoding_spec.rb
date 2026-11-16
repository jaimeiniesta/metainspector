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
