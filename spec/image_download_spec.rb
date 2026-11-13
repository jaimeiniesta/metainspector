require 'spec_helper'
require 'socket'

RSpec.describe 'bounded image downloads' do
  let(:png) { "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [37, 29].pack('NN') + "\x08\x02\x00\x00\x00".b }

  it 'inherits proxy and TLS options without modifying caller-owned hashes' do
    image = 'https://images.example/image.png'
    stub_request(:get, image).to_return(body: png)
    ssl = { verify: false }.freeze
    redirect = { limit: 2 }.freeze
    options = { proxy: 'http://proxy.example:3128', ssl: ssl, redirect: redirect }.freeze
    expect(Faraday).to receive(:new).with(hash_including(proxy: options[:proxy], ssl: ssl)).and_call_original
    page = MetaInspector.new('https://page.example/', document: %(<img src="#{image}">), faraday_options: options)
    expect(page.images.with_size).to eq([[image, 37, 29]])
    expect(options).to eq(proxy: 'http://proxy.example:3128', ssl: ssl, redirect: redirect)
  end

  it 'does not cache streamed image responses' do
    cache = Class.new(Hash) do
      def read(key); self[key]; end
      def write(key, value); self[key] = value; end
    end.new
    stub_request(:get, 'https://images.example/image.png').to_return(body: png,
      headers: { 'Cache-Control' => 'public, max-age=3600' })
    2.times do
      page = MetaInspector.new('https://page.example/', document: '<img src="https://images.example/image.png">',
        faraday_options: { faraday_http_cache: { store: cache } })
      expect(page.images.with_size.first.last(2)).to eq([37, 29])
    end
    expect(cache).to be_empty
    expect(a_request(:get, 'https://images.example/image.png')).to have_been_made.twice
  end

  context 'with a real HTTP server' do
    around do |example|
      @server = TCPServer.new('127.0.0.1', 0)
      @url = "http://127.0.0.1:#{@server.addr[1]}/image"
      # WebMock buffers real responses before yielding to Net::HTTP's block.
      # Disable its adapter here to exercise actual incremental reads.
      WebMock.disable!
      example.run
    ensure
      @server&.close
      @worker&.kill
      @worker&.join
      WebMock.enable!
      WebMock.disable_net_connect!
    end

    def serve(&block)
      @worker = Thread.new do
        socket = @server.accept
        while (line = socket.gets) && line != "\r\n"; end
        block.call(socket)
      rescue Errno::EPIPE, Errno::ECONNRESET, IOError
        # Reaching the byte/time limit closes the peer connection.
      ensure
        socket&.close
      end
    end

    it 'counts a fully received chunked image without a content length' do
      serve do |socket|
        socket.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n")
        socket.write("#{png.bytesize.to_s(16)}\r\n")
        socket.write(png)
        socket.write("\r\n0\r\n\r\n")
      end
      page = MetaInspector.new('http://page.example/', document: %(<img src="#{@url}">))
      expect(page.images.with_details.first).to include(type: :png, file_size: png.bytesize)
    end

    it 'bounds binary IO and stops a server that ignores Range before reading its full body' do
      sent = 0
      serve do |socket|
        socket.write("HTTP/1.1 200 OK\r\nContent-Length: 4194304\r\nContent-Type: image/png\r\nConnection: close\r\n\r\n")
        socket.write(png)
        1024.times do
          socket.write('x' * 4096)
          sent += 4096
          sleep 0.002
        end
      end
      expect(FastImage).to receive(:size).with(an_instance_of(StringIO)) do |io|
        expect(io.string.bytesize).to eq(256 * 1024)
        expect(io.string.encoding).to eq(Encoding::BINARY)
        [37, 29]
      end
      page = MetaInspector.new('http://page.example/', document: %(<img src="#{@url}">))
      expect(page.images.with_size).to eq([[@url, 37, 29]])
      expect(sent).to be < 4 * 1024 * 1024
    end

    it 'also stops oversized redirect bodies before following their location' do
      sent = 0
      serve do |socket|
        socket.write("HTTP/1.1 302 Found\r\nLocation: /next\r\nContent-Length: 4194304\r\nConnection: close\r\n\r\n")
        1024.times do
          socket.write('x' * 4096)
          sent += 4096
          sleep 0.0005
        end
      end
      page = MetaInspector.new('http://page.example/', document: %(<img src="#{@url}">))
      expect(page.images.with_size).to eq([[@url, 0, 0]])
      expect(sent).to be < 4 * 1024 * 1024
    end

    it 'bounds the entire image request even while response data keeps arriving' do
      serve do |socket|
        socket.write("HTTP/1.1 200 OK\r\nContent-Length: 1000000\r\nConnection: close\r\n\r\n")
        loop do
          socket.write('x')
          sleep 0.02
        end
      end
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      page = MetaInspector.new('http://page.example/', document: %(<img src="#{@url}">))
      expect(page.images.with_size).to eq([[@url, 0, 0]])
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      expect(elapsed).to be < 2.8
    end
  end
end
