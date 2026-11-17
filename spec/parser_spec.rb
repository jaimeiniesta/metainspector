require 'spec_helper'
require 'json'

describe MetaInspector::Parser do
  let(:doc)    { MetaInspector::Document.new('http://pagerankalert.com') }
  let(:parser) { MetaInspector::Parser.new(doc) }

  it "should have a Nokogiri::HTML5::Document as parsed" do
    expect(parser.parsed.class).to eq(Nokogiri::HTML5::Document)
  end

  it "should return the document as a string" do
    expect(parser.to_s.class).to eq(String)
  end

  describe 'parser resource limits' do
    def nested_html(depth)
      "<html><body>#{'<div>' * depth}<a href=\"/deep\">deep</a>#{'</div>' * depth}" \
        '<a href="/after">after</a><h1>After</h1></body></html>'
    end

    # Past libxml2's nesting limit (256), within the HTML5 one (400)
    let(:deep_html) { nested_html(300) }
    # Past both limits
    let(:too_deep_html) { nested_html(500) }

    it 'parses a passed document nested past the libxml2 limit but within the HTML5 one' do
      page = MetaInspector.new('http://example.com', document: deep_html)

      expect(page.links.raw).to eq(['/deep', '/after'])
      expect(page.h1).to eq(['After'])
    end

    it 'parses a downloaded document nested past the libxml2 limit but within the HTML5 one' do
      stub_request(:get, 'http://example.com/').to_return(
        body: deep_html, headers: { 'Content-Type' => 'text/html' }
      )

      expect(MetaInspector.new('http://example.com').links.raw).to eq(['/deep', '/after'])
    end

    it 'parses markup that only nests in the libxml2 tree' do
      # HTML5 closes the open <div>s at </section>; libxml2's HTML4 parser
      # leaves them open, so each section nests inside the previous one.
      sections = (1..100).map { |i| %(<section><div><div><a href="/r#{i}">Read more</a></section>) }.join
      page = MetaInspector.new('http://example.com', document: "<title>Release notes</title>#{sections}")

      expect(page.title).to eq('Release notes')
      expect(page.links.raw.size).to eq(100)
      expect(page.parsed.css('section section')).to be_empty
    end

    it 'rejects a passed document nested past the HTML5 limit' do
      expect do
        MetaInspector.new('http://example.com', document: too_deep_html)
      end.to raise_error(MetaInspector::ParserError, /tree depth limit/)
    end

    it 'rejects a downloaded document nested past the HTML5 limit' do
      stub_request(:get, 'http://example.com/').to_return(
        body: too_deep_html, headers: { 'Content-Type' => 'text/html' }
      )

      expect do
        MetaInspector.new('http://example.com')
      end.to raise_error(MetaInspector::ParserError, /tree depth limit/)
    end

    # libxml2 stops reading at its depth limit, so it can't check the size of
    # what comes after. The same size limits apply to the HTML5 tree instead.
    {
      'text' => '<p>%s</p>',
      'attribute value' => '<p title="%s">t</p>',
      'comment' => '<!--%s-->',
      'script' => '<script>%s</script>'
    }.each do |kind, template|
      it "rejects an oversized #{kind} after nesting past the libxml2 limit" do
        html = "<html><body>#{'<div>' * 300}#{format(template, 'x' * 10_000_001)}</body></html>"

        expect do
          MetaInspector.new('http://example.com', document: html)
        end.to raise_error(MetaInspector::ParserError, /Resource limit exceeded/)
      end
    end

    it 'accepts nodes at the size limit after nesting past the libxml2 limit' do
      html = "<html><body>#{'<div>' * 300}<p title=\"#{'x' * 10_000_000}\">#{'y' * 10_000_000}</p></body></html>"

      expect(MetaInspector.new('http://example.com', document: html).parsed.at_css('p')['title'].size)
        .to eq(10_000_000)
    end

    it 'rejects a document truncated by the libxml2 limit when HTML5 cannot parse its encoding' do
      html = "<meta charset=\"UTF-7\">#{deep_html}".b

      expect do
        MetaInspector.new('http://example.com', document: html)
      end.to raise_error(MetaInspector::ParserError, /Excessive depth in document/)
    end

    it 'wraps the HTML5 tree depth limit when HTML4 would close nested paragraphs' do
      html = '<div><h1><p>' * 220 + 'deep'

      expect do
        MetaInspector.new('http://example.com', document: html)
      end.to raise_error(MetaInspector::ParserError, /tree depth limit/)
    end

    describe 'with allow_non_html_content' do
      def non_html_page(body, content_type)
        stub_request(:get, 'http://example.com/file').to_return(
          body: body, headers: { 'Content-Type' => content_type }
        )
        MetaInspector.new('http://example.com/file', allow_non_html_content: true)
      end

      it 'returns binary content nested past both depth limits' do
        body = "%PDF-1.7\n".b + ('<x>' * 500) + 'end'
        page = non_html_page(body, 'application/pdf')

        expect(page.content_type).to eq('application/pdf')
        expect(page.to_s).to eq(body)
        expect(page.parsed.errors.map(&:message)).to include(/Excessive depth in document/)
        expect { page.to_hash }.not_to raise_error
      end

      it 'returns feeds nested past the HTML5 depth limit' do
        categories = '<category term="tag"/>' * 500
        page = non_html_page(
          "<?xml version=\"1.0\"?><feed><title>Feed</title>#{categories}<link href=\"/entry\"/></feed>",
          'application/atom+xml'
        )

        expect(page.content_type).to eq('application/atom+xml')
        expect(page.parsed.at_css('feed > title').text).to eq('Feed')
        expect(page.parsed.css('category').size).to eq(500)
        expect { page.to_hash }.not_to raise_error
      end

      it 'still rejects HTML responses nested past the HTML5 limit' do
        stub_request(:get, 'http://example.com/').to_return(
          body: too_deep_html, headers: { 'Content-Type' => 'text/html' }
        )

        expect do
          MetaInspector.new('http://example.com', allow_non_html_content: true)
        end.to raise_error(MetaInspector::ParserError, /tree depth limit/)
      end

      it 'still enforces max_html_bytes' do
        stub_request(:get, 'http://example.com/file').to_return(
          body: 'x' * 100, headers: { 'Content-Type' => 'application/pdf' }
        )

        expect do
          MetaInspector.new('http://example.com/file', allow_non_html_content: true, max_html_bytes: 10)
        end.to raise_error(MetaInspector::ParserError)
      end
    end

    it 'does not introduce an attribute count limit' do
      attributes = (1..500).map { |i| "data-#{i}=\"#{i}\"" }.join(' ')
      page = MetaInspector.new('http://example.com', document: "<h1 #{attributes}><p>Hello</p></h1>")

      expect(page.h1).to eq(['Hello'])
    end

    {
      'text node' => ['<p>', '</p>'],
      'attribute value' => ['<p title="', '">text</p>'],
      'comment' => ['<!--', '-->']
    }.each do |kind, (opening, closing)|
      it "does not silently lose content after an oversized #{kind}" do
        html = "#{opening}#{'x' * 12_000_000}#{closing}<a href=\"/after\">after</a>"

        # Some system libxml2 versions allow oversized attributes and comments.
        if Nokogiri::HTML(html).at_css('a')
          page = MetaInspector.new('http://example.com', document: html)
          expect(page.links.raw).to eq(['/after'])
        else
          expect do
            MetaInspector.new('http://example.com', document: html)
          end.to raise_error(MetaInspector::ParserError, /Resource limit exceeded|huge text node/)
        end
      end
    end

    it 'preserves all links and headings below the nesting limit' do
      html = "<html><body>#{'<div>' * 250}<a href=\"/deep\">deep</a>#{'</div>' * 250}" \
        '<a href="/after">after</a><h1>After</h1></body></html>'
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.links.raw).to eq(['/deep', '/after'])
      expect(page.h1).to eq(['After'])
    end

    it 'continues recovering from ordinary HTML errors' do
      html = '<html><body><unexpected>text</unexpected><a href="/after">after</a></body></html>'
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.parsed.errors).not_to be_empty
      expect(page.links.raw).to eq(['/after'])
    end

    it 'continues recovering from fatal encoding errors that do not truncate the document' do
      html = "<meta charset=\"UTF-8\"><title>caf\xE9</title><a href=\"/after\">after</a>".b
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.parsed.errors.any?(&:fatal?)).to be(true)
      expect(page.links.raw).to eq(['/after'])
    end

    it 'rejects the nonfatal huge-text diagnostic from older system libxml2 versions' do
      parsed = Nokogiri::HTML('<p>truncated</p>')
      error = Nokogiri::XML::SyntaxError.new('xmlSAX2Characters: huge text node')
      allow(error).to receive(:level).and_return(2)
      parsed.errors << error
      allow(Nokogiri).to receive(:HTML).and_return(parsed)

      expect do
        MetaInspector.new('http://example.com', document: '<p>text</p><a href="/after">after</a>')
      end.to raise_error(MetaInspector::ParserError, /huge text node/)
    end
  end

  describe 'invalid bytes in a passed document' do
    let(:html) do
      "<html><head><title>caf\xE9</title></head><body><h1>caf\xE9</h1></body></html>"
    end
    let(:page) { MetaInspector.new('http://example.com', document: html) }

    it 'replaces invalid bytes in the title' do
      expect(page.title).to eq("caf\uFFFD")
    end

    it 'returns a best title without an encoding error' do
      expect(page.best_title).to eq("caf\uFFFD")
    end

    it 'returns headings without an encoding error' do
      expect(page.h1).to eq(["caf\uFFFD"])
    end

    it 'returns serializable metadata without an encoding error' do
      expect(JSON.parse(JSON.generate(page.to_hash))).to include(
        'title' => "caf\uFFFD", 'best_title' => "caf\uFFFD", 'h1' => ["caf\uFFFD"]
      )
    end

    it 'preserves the original document, including when frozen' do
      original = html.dup
      html.freeze

      expect(page.title).to eq("caf\uFFFD")
      expect(page.to_s).to equal(html)
      expect(html).to eq(original)
    end
  end

  describe 'valid bytes in a passed document' do
    it 'uses the first charset declaration in a binary string' do
      html = '<html><head><meta charset="utf-8"><title>中国</title></head>' \
        '<body><p>新闻</p><meta charset="gbk"><a href="/a">a</a></body></html>'
      page = MetaInspector.new('http://example.com', document: html.b)

      expect(page.title).to eq('中国')
      expect(page.links.raw).to eq(['/a'])
      expect(page.parsed.encoding).to eq('UTF-8')
    end

    [
      '<meta http-equiv="content-type" content="text/html; CHARSET = UTF-8">',
      %q{<META CONTENT="text/html; charset='UTF-8'" HTTP-EQUIV="Content-Type">},
      '<meta charset=UTF-8>',
      '<meta data-note="a > b" charset="UTF-8">'
    ].each do |declaration|
      it "honors the first declaration written as #{declaration}" do
        html = "<html><head>#{declaration}<meta charset=gbk><title>中国</title></head>" \
          '<body><a href="/a">a</a></body></html>'
        page = MetaInspector.new('http://example.com', document: html.b)

        expect(page.title).to eq('中国')
        expect(page.links.raw).to eq(['/a'])
      end
    end

    it 'uses a legacy declaration before a conflicting modern declaration' do
      html = '<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">' \
        '<meta charset=UTF-8><title>Café</title><a href="/a">a</a>'
      page = MetaInspector.new('http://example.com', document: html.encode('ISO-8859-1').b)

      expect(page.title).to eq('Café')
      expect(page.links.raw).to eq(['/a'])
    end

    it 'ignores meta-like text in comments, scripts and other attributes' do
      html = '<!-- <meta charset=gbk> --><script>var tag = "<meta charset=gbk>";</script>' +
        %q{<meta name="example" content='<meta charset=gbk>'>} +
        '<meta charset=UTF-8><meta charset=gbk><title>中国</title><a href="/a">a</a>'
      page = MetaInspector.new('http://example.com', document: html.b)

      expect(page.title).to eq('中国')
      expect(page.links.raw).to eq(['/a'])
    end

    %w[textarea xmp title iframe noembed].each do |element|
      it "ignores meta-like text inside #{element}" do
        html = "<#{element}><meta charset=gbk></#{element}><meta charset=UTF-8>" \
          '<h1>中国</h1><a href="/a">a</a>'
        page = MetaInspector.new('http://example.com', document: html.b)

        expect(page.h1).to eq(['中国'])
        expect(page.links.raw).to eq(['/a'])
      end
    end

    %w[UTF-8 UTF-16LE UTF-16BE UTF-32LE UTF-32BE].each do |encoding|
      it "honors a #{encoding} BOM before conflicting meta declarations" do
        html = "\uFEFF<html><head><meta charset=gbk><title>中国</title></head>" \
          '<body><a href="/a">a</a></body></html>'
        body = html.encode(encoding).b.freeze
        page = MetaInspector.new('http://example.com', document: body)

        expect(page.title).to eq('中国')
        expect(page.links.raw).to eq(['/a'])
        expect(page.to_s).to equal(body)
      end
    end

    it 'preserves an explicitly tagged string over conflicting meta declarations' do
      html = '<meta charset=gbk><title>中国</title><meta charset=UTF-8><a href="/a">a</a>'
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.title).to eq('中国')
      expect(page.links.raw).to eq(['/a'])
    end

    it 'preserves the valid Shift_JIS encoding name when parsing headings' do
      html = '<meta charset="Shift_JIS"><h1><p>日本</p></h1>'.encode('Shift_JIS').b
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.h1).to eq(['日本'])
    end

    %w[latin1 L1 ISO_8859-1 ISO_8859-1:1987].each do |charset|
      it "accepts the libxml2 charset alias #{charset} for HTML5 headings" do
        html = "<meta charset=\"#{charset}\"><h1><p>Café</p></h1>".encode('ISO-8859-1').b
        page = MetaInspector.new('http://example.com', document: html)

        expect(page.h1).to eq(['Café'])
      end
    end

    it 'retains HTML4 support for encodings without a Ruby converter' do
      html = '<meta charset="UTF-7"><title>Caf+AOk-</title>'.b
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.title).to eq('Café')
    end

    it 'preserves valid UTF-8 characters around invalid bytes' do
      html = "<title>Café \xFF 日本語</title>"
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.title).to eq("Café \uFFFD 日本語")
    end

    it 'preserves characters in a valid non-UTF-8 string' do
      html = '<title>Café</title>'.encode('ISO-8859-1')
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.title).to eq('Café')
    end

    it 'allows Nokogiri to detect the charset of a binary string' do
      html = '<meta charset="ISO-8859-1"><title>Café</title>'.encode('ISO-8859-1').b
      page = MetaInspector.new('http://example.com', document: html)

      expect(page.title).to eq('Café')
    end

    it 'decodes GBK characters in a binary document declaring gb2312 before HTML5 parsing' do
      html = '<meta charset="gb2312"><h1><p>朱镕基</p></h1><a href="/after">after</a>'.encode('GBK').b
      original = html.dup
      page = MetaInspector.new('http://example.com', document: html.freeze)

      expect(page.h1).to eq(['朱镕基'])
      expect(page.best_title).to eq('朱镕基')
      expect(page.links.raw).to eq(['/after'])
      expect(page.to_s).to equal(html)
      expect(html).to eq(original)
    end
  end
end
