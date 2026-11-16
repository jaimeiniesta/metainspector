require 'spec_helper'

describe MetaInspector, 'content type normalization' do
  let(:page_url) { 'http://example.com/content-type' }
  let(:html) { '<html><head><title>Downloaded page</title></head></html>' }

  [false, true].each do |head_first|
    context "with head_first: #{head_first}" do
      ['Text/HTML; charset=utf-8', 'text/html ; charset=utf-8', " \tTEXT/HTML\t; charset=utf-8"].each do |content_type|
        it "parses HTML served as #{content_type.inspect}" do
          stub_request(:head, page_url).to_return(headers: { 'Content-Type' => content_type }) if head_first
          stub_request(:get, page_url).to_return(body: html, headers: { 'Content-Type' => content_type })

          page = MetaInspector.new(page_url, head_first: head_first)

          expect(page.title).to eq('Downloaded page')
          expect(page.content_type).to eq('text/html')
          expect(page.to_hash['content_type']).to eq('text/html')
          expect(page.response.headers['content-type']).to eq(content_type)
        end
      end

      it 'still rejects non-HTML content after normalization' do
        stub_request(:head, page_url).to_return(headers: { 'Content-Type' => 'Application/PDF ; version=1.7' }) if head_first
        get_request = stub_request(:get, page_url)
          .to_return(body: 'PDF data', headers: { 'Content-Type' => 'Application/PDF ; version=1.7' })

        expect do
          MetaInspector.new(page_url, head_first: head_first)
        end.to raise_error(MetaInspector::NonHtmlError,
          'The url provided contains application/pdf content instead of text/html content')

        expect(get_request).not_to have_been_requested if head_first
      end

      it 'normalizes non-HTML content when explicitly allowed' do
        stub_request(:head, page_url).to_return(headers: { 'Content-Type' => 'Text/Plain ; charset=utf-8' }) if head_first
        stub_request(:get, page_url).to_return(body: 'Plain text', headers: { 'Content-Type' => 'Text/Plain ; charset=utf-8' })

        page = MetaInspector.new(page_url, head_first: head_first, allow_non_html_content: true)

        expect(page.to_s).to eq('Plain text')
        expect(page.content_type).to eq('text/plain')
      end
    end
  end
end
