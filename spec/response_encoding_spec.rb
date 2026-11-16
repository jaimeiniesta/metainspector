require 'spec_helper'
require 'zlib'

RSpec.describe 'conflicting page charset declarations' do
  let(:url) { 'https://encoding.example/page' }
  let(:html) do
    '<html><head><meta charset=utf-8><title>中国</title></head>' \
      '<body><p>新闻</p><meta charset=gbk><a href="/a">a</a></body></html>'
  end

  it 'uses the first meta charset when Content-Type has no charset' do
    body = html.b
    stub_request(:get, url).to_return(body: body, headers: { 'Content-Type' => 'text/html' })

    page = MetaInspector.new(url)

    expect(page.title).to eq('中国')
    expect(page.links.raw).to eq(['/a'])
    expect(page.response.body).to eq(body)
    expect(page.to_s.encoding).to eq(Encoding::BINARY)
  end

  it 'preserves the HTTP charset over conflicting meta declarations' do
    body = html.encode('GBK').b
    stub_request(:get, url).to_return(body: body, headers: { 'Content-Type' => 'text/html; charset=GBK' })

    page = MetaInspector.new(url)

    expect(page.title).to eq('中国')
    expect(page.links.raw).to eq(['/a'])
    expect(page.to_s.encoding).to eq(Encoding.find('GBK'))
  end

  it 'preserves a forced encoding over conflicting meta declarations' do
    stub_request(:get, url).to_return(body: html.b, headers: { 'Content-Type' => 'text/html; charset=GBK' })

    page = MetaInspector.new(url, encoding: 'UTF-8')

    expect(page.title).to eq('中国')
    expect(page.links.raw).to eq(['/a'])
  end

  it 'honors a UTF-8 BOM when Content-Type has no charset' do
    body = "\xEF\xBB\xBF".b + html.sub('charset=utf-8', 'charset=gbk').b
    stub_request(:get, url).to_return(body: body, headers: { 'Content-Type' => 'text/html' })

    page = MetaInspector.new(url)

    expect(page.title).to eq('中国')
    expect(page.links.raw).to eq(['/a'])
    expect(page.response.body).to eq(body)
  end
end

RSpec.describe 'legacy HTML charset labels' do
  let(:url) { 'https://encoding.example/page' }

  [
    ['gb2312', 'GBK', '朱镕基'],
    ['shift_jis', 'Windows-31J', '①㈱髙'],
    ['euc-kr', 'CP949', '똠'],
    ['big5', 'Big5-HKSCS', '嗰'],
    ['iso-8859-1', 'Windows-1252', 'It’s €5']
  ].each do |label, encoding, title|
    context "with #{label} containing #{encoding} characters" do
      let(:html) do
        %(<html><head><meta charset="#{label}"><title>#{title}</title></head>) +
          '<body><a href="/after">after</a></body></html>'
      end
      let(:bytes) { html.encode(encoding).b }

      def expect_complete_page(page, title)
        expect(page.title).to eq(title)
        expect(page.links.raw).to eq(['/after'])
        expect(page.parsed.errors.select(&:fatal?)).to be_empty
      end

      it 'parses a supplied binary document without changing its bytes or declared charset' do
        original = bytes.dup
        page = MetaInspector.new(url, document: bytes.freeze)

        expect_complete_page(page, title)
        expect(page.charset).to eq(label)
        expect(page.to_s).to equal(bytes)
        expect(bytes).to eq(original)
      end

      it 'parses a supplied string tagged with the strict encoding before scrubbing' do
        tagged = bytes.dup.force_encoding(label).freeze
        page = MetaInspector.new(url, document: tagged)

        expect_complete_page(page, title)
        expect(page.to_s).to equal(tagged)
      end

      it 'parses a response declaring its charset only in HTML' do
        stub_request(:get, url).to_return(body: bytes, headers: { 'Content-Type' => 'text/html' })

        expect_complete_page(MetaInspector.new(url), title)
      end

      it 'preserves the first legacy declaration when a later meta declares UTF-8' do
        body = html.sub('</head>', '<meta charset="UTF-8"></head>').encode(encoding).b
        stub_request(:get, url).to_return(body: body, headers: { 'Content-Type' => 'text/html' })

        expect_complete_page(MetaInspector.new(url, document: body.freeze), title)
        expect_complete_page(MetaInspector.new(url), title)
      end

      it 'parses an http-equiv declaration with mixed case and reordered attributes' do
        body = html.sub(%(<meta charset="#{label}">),
                        %(<META content="text/html; charset=#{label.upcase}" HTTP-EQUIV="Content-Type">))
                   .encode(encoding).b
        stub_request(:get, url).to_return(body: body, headers: { 'Content-Type' => 'text/html' })

        expect_complete_page(MetaInspector.new(url), title)
      end

      it 'parses a charset declared only in the HTTP header, preserving the raw body' do
        body = html.sub(%(<meta charset="#{label}">), '').encode(encoding).b
        stub_request(:get, url).to_return(body: body, headers: {
          'Content-Type' => "text/html; charset=#{label}"
        })
        page = MetaInspector.new(url)

        expect_complete_page(page, title)
        expect(page.response.body.b).to eq(body)
        expect(page.response.body.encoding).to eq(Encoding.find(label))
      end

      it 'parses the HTTP charset after gzip decompression' do
        stub_request(:get, url).to_return(body: Zlib.gzip(bytes), headers: {
          'Content-Type' => "text/html; charset=#{label}", 'Content-Encoding' => 'gzip'
        })

        expect_complete_page(MetaInspector.new(url), title)
      end

      it 'supports a forced legacy encoding without discarding superset characters' do
        stub_request(:get, url).to_return(body: bytes, headers: { 'Content-Type' => 'text/html' })

        expect_complete_page(MetaInspector.new(url, encoding: label), title)
      end
    end
  end

  it 'keeps a UTF-8 string authoritative over a legacy meta declaration' do
    html = '<meta charset="gb2312"><title>朱镕基</title><a href="/after">after</a>'

    page = MetaInspector.new(url, document: html)

    expect(page.title).to eq('朱镕基')
    expect(page.links.raw).to eq(['/after'])
  end

  it 'uses Windows-31J character mappings for both binary and tagged strings' do
    title = '～∥－￠￡￢'
    html = %(<meta charset="shift_jis"><title>#{title}</title><a href="/after">after</a>)
    bytes = html.encode('Windows-31J')

    [bytes.b, bytes.dup.force_encoding('Shift_JIS')].each do |document|
      page = MetaInspector.new(url, document: document)

      expect(page.title).to eq(title)
      expect(page.links.raw).to eq(['/after'])
    end
  end

  it 'keeps a forced UTF-8 encoding authoritative over the HTTP charset' do
    stub_request(:get, url).to_return(body: '<title>朱镕基</title>'.b, headers: {
      'Content-Type' => 'text/html; charset=gb2312'
    })

    expect(MetaInspector.new(url, encoding: 'UTF-8').title).to eq('朱镕基')
  end
end

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
