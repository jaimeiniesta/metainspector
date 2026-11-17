require 'spec_helper'
require 'socket'

RSpec.describe 'bounded page responses' do
  let(:url) { 'https://size.example/page' }

  [nil, 'gzip', 'deflate', 'raw deflate', 'gzip, deflate'].each do |compression|
    [false, true].each do |head_first|
      it "preserves #{compression || 'plain'} HTML and its charset with head_first: #{head_first}" do
        html = '<title>Café</title>'.encode('Windows-1252')
        body = case compression
               when 'gzip' then Zlib.gzip(html)
               when 'deflate' then Zlib::Deflate.deflate(html)
               when 'raw deflate'
                 deflater = Zlib::Deflate.new(nil, -Zlib::MAX_WBITS)
                 begin
                   deflater.deflate(html, Zlib::FINISH)
                 ensure
                   deflater.close
                 end
               when 'gzip, deflate' then Zlib::Deflate.deflate(Zlib.gzip(html))
               else html
               end
        headers = { 'Content-Type' => 'text/html; charset=Windows-1252', 'Content-Length' => '999999' }
        headers['Content-Encoding'] = compression == 'raw deflate' ? 'deflate' : compression if compression
        stub_request(:head, url).to_return(headers: headers)
        stub_request(:get, url).to_return(body: body, headers: headers)

        page = MetaInspector.new(url, max_html_bytes: 128, head_first: head_first)
        expect(page.title).to eq('Café')
        expect(page.response.body).to eq(html)
        expect(page.to_s.encoding).to eq(Encoding::Windows_1252)
      end
    end
  end

  it 'accepts exactly the limit in bytes' do
    html = '<title>é</title>'
    stub_request(:get, url).to_return(body: html, headers: { 'Content-Type' => 'text/html; charset=UTF-8' })
    expect(MetaInspector.new(url, max_html_bytes: html.bytesize).title).to eq('é')
  end

  it 'preserves a quoted HTTP charset on streamed uncompressed HTML' do
    html = '<title>Café</title>'.encode('Windows-1252')
    stub_request(:get, url).to_return(body: html, headers: { 'Content-Type' => 'text/html; charset="Windows-1252"' })
    page = MetaInspector.new(url, max_html_bytes: 128)
    expect(page.title).to eq('Café')
    expect(page.to_s.encoding).to eq(Encoding::Windows_1252)
  end

  it 'caches complete streamed responses for subsequent requests' do
    cache = Class.new(Hash) do
      def read(key); self[key]; end
      def write(key, value); self[key] = value; end
    end.new
    stub_request(:get, url).to_return(body: Zlib.gzip('<title>cached</title>'), headers: {
      'Content-Encoding' => 'gzip', 'Cache-Control' => 'public, max-age=3600'
    })
    2.times do
      page = MetaInspector.new(url, max_html_bytes: 128, faraday_options: { faraday_http_cache: { store: cache } })
      expect(page.title).to eq('cached')
    end
    expect(a_request(:get, url)).to have_been_made.once
  end

  it 'accepts an empty response with a zero limit' do
    stub_request(:get, url).to_return(body: '')
    expect(MetaInspector.new(url, max_html_bytes: 0).to_s).to eq('')
  end

  it 'limits compressed bytes even if the decoded HTML fits' do
    body = Zlib.gzip('<title>x</title>')
    stub_request(:get, url).to_return(body: body, headers: { 'Content-Encoding' => 'gzip' })
    expect { MetaInspector.new(url, max_html_bytes: 16) }.to raise_error(MetaInspector::ParserError)
  end

  it 'reads concatenated gzip members' do
    body = Zlib.gzip('<title>') + Zlib.gzip('joined</title>')
    stub_request(:get, url).to_return(body: body, headers: { 'Content-Encoding' => 'gzip' })
    expect(MetaInspector.new(url, max_html_bytes: 128).title).to eq('joined')
  end

  it 'limits the combined output of concatenated gzip members' do
    body = Zlib.gzip('x' * 100) * 2
    stub_request(:get, url).to_return(body: body, headers: { 'Content-Encoding' => 'gzip' })
    expect { MetaInspector.new(url, max_html_bytes: 128) }.to raise_error(MetaInspector::ParserError)
  end

  %w[gzip deflate].each do |compression|
    it "keeps malformed #{compression} errors as RequestError" do
      stub_request(:get, url).to_return(body: 'not compressed', headers: { 'Content-Encoding' => compression })
      expect { MetaInspector.new(url, max_html_bytes: 128) }.to raise_error(MetaInspector::RequestError) { |error|
        expect(error.cause).to be_a(Zlib::Error)
      }
    end
  end

  it 'keeps a fresh body for each redirect' do
    stub_request(:get, url).to_return(status: 302, body: 'redirect', headers: { 'Location' => '/next' })
    stub_request(:get, 'https://size.example/next').to_return(body: '<title>next</title>')
    expect(MetaInspector.new(url, max_html_bytes: 32).to_s).to eq('<title>next</title>')
  end

  it 'rejects oversized redirect bodies before following their location' do
    stub_request(:get, url).to_return(status: 302, body: 'x' * 100, headers: { 'Location' => '/next' })
    expect { MetaInspector.new(url, max_html_bytes: 32) }.to raise_error(MetaInspector::ParserError)
    expect(a_request(:get, 'https://size.example/next')).not_to have_been_made
  end

  it 'checks cached bodies against the limit of the current request' do
    cache = Class.new(Hash) do
      def read(key); self[key]; end
      def write(key, value); self[key] = value; end
    end.new
    stub_request(:get, url).to_return(body: Zlib.gzip('<title>cached</title>' + ' ' * 1024), headers: {
      'Content-Encoding' => 'gzip', 'Cache-Control' => 'public, max-age=3600'
    })
    options = { faraday_options: { faraday_http_cache: { store: cache } } }
    expect(MetaInspector.new(url, **options).title).to eq('cached')
    expect { MetaInspector.new(url, **options, max_html_bytes: 128) }.to raise_error(MetaInspector::ParserError)
    expect(a_request(:get, url)).to have_been_made.once
  end

  %w[gzip deflate].each do |compression|
    it "stops expanding #{compression} before reaching a corrupt trailer" do
      body = '<p>' + 'x' * (4 * 1024 * 1024) + '</p>'
      compressed = compression == 'gzip' ? Zlib.gzip(body) : Zlib::Deflate.deflate(body)
      compressed.setbyte(-1, compressed.getbyte(-1) ^ 255)
      stub_request(:get, url).to_return(body: compressed, headers: {
        'Content-Type' => 'text/html', 'Content-Encoding' => compression
      })

      expect { MetaInspector.new(url, max_html_bytes: 64 * 1024) }
        .to raise_error(MetaInspector::ParserError, /limit.*65536 bytes/)
    end
  end

  context 'with a real HTTP server' do
    around do |example|
      @server = TCPServer.new('127.0.0.1', 0)
      @url = "http://127.0.0.1:#{@server.addr[1]}/page"
      # WebMock buffers real responses, hiding incremental reads.
      WebMock.disable!
      example.run
    ensure
      @server&.close
      @worker&.kill
      @worker&.join
      WebMock.enable!
      WebMock.disable_net_connect!
    end

    it 'stops an oversized chunked response before the server finishes sending' do
      sent = 0
      @worker = Thread.new do
        socket = @server.accept
        while (line = socket.gets) && line != "\r\n"; end
        socket.write("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n")
        1024.times do
          socket.write("1000\r\n#{'x' * 4096}\r\n")
          sent += 4096
          sleep 0.001
        end
        socket.write("0\r\n\r\n")
      rescue Errno::EPIPE, Errno::ECONNRESET, IOError
        # The size limit closes the connection.
      ensure
        socket&.close
      end

      expect { MetaInspector.new(@url, max_html_bytes: 64 * 1024) }
        .to raise_error(MetaInspector::ParserError)
      expect(sent).to be < 4 * 1024 * 1024
    end
  end
end
