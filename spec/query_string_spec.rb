require 'spec_helper'
require 'socket'

# WebMock normalizes request URIs before matching, so these examples read the
# request line from a real socket to see the query exactly as it was sent.
RSpec.describe 'query strings' do
  around do |example|
    @server = TCPServer.new('127.0.0.1', 0)
    @base = "http://127.0.0.1:#{@server.addr[1]}"
    @targets = []
    WebMock.disable!
    example.run
  ensure
    @server&.close
    @worker&.kill
    @worker&.join
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  def serve(responses = {})
    @worker = Thread.new do
      loop do
        socket = @server.accept
        method, target = socket.gets.split
        while (line = socket.gets) && line != "\r\n"; end
        @targets << target
        status, headers, body = responses.fetch(target.split('?').first, [200, { 'Content-Type' => 'text/html' }, ''])
        header_lines = headers.merge('Content-Length' => body.bytesize, 'Connection' => 'close')
                              .map { |name, value| "#{name}: #{value}\r\n" }.join
        socket.write("HTTP/1.1 #{status} OK\r\n#{header_lines}\r\n")
        socket.write(body) unless method == 'HEAD'
        socket.close
      end
    rescue IOError
      # The server is closed after each example.
    end
  end

  [
    '/?b=2&a=1',
    '/?tag=x&tag=y',
    '/?q=a%20b',
    '/?q=1;r=2',
    '/?a=b=c',
    '/?ids=1,2,3',
    '/?a[]=1&a[]=2',
    '/?=x',
    '/?%61=1',
    '/?q=caf%E9'
  ].each do |target|
    it "requests #{target} as given and reports it in url" do
      serve
      page = MetaInspector.new("#{@base}#{target}", normalize_url: false)
      expect(@targets).to eq([target])
      expect(page.url).to eq("#{@base}#{target}")
    end
  end

  it 'requests a non-UTF-8 escape with URL normalization enabled' do
    serve
    MetaInspector.new("#{@base}/?q=caf%E9")
    expect(@targets).to eq(['/?q=caf%E9'])
  end

  # With normalize_url, the default, only what can't be sent is escaped (#613).
  {
    '/?q=1;r=2' => '/?q=1;r=2',
    '/?a[]=1&a[]=2' => '/?a[]=1&a[]=2',
    '/?q=a%2fb' => '/?q=a%2fb',
    '/?%61=1' => '/?%61=1',
    '/?q=%7e' => '/?q=%7e',
    '/?q=caf%c3%a9' => '/?q=caf%c3%a9',
    '/?q=(1)*!$+,:@/?' => '/?q=(1)*!$+,:@/?',
    '/?q=café' => '/?q=caf%C3%A9',
    '/?q=a|b' => '/?q=a%7Cb',
    '/?q={x}' => '/?q=%7Bx%7D',
    '/?q=50%' => '/?q=50%25',
    '/?q=%zz' => '/?q=%25zz',
    '/?q=a b' => '/?q=a%20b',
    '/?q="<x>"' => '/?q=%22%3Cx%3E%22',
    '/?q=a^b\\c`d' => '/?q=a%5Eb%5Cc%60d'
  }.each do |given, sent|
    it "requests #{given} as #{sent} with URL normalization" do
      serve
      page = MetaInspector.new("#{@base}#{given}")
      expect(@targets).to eq([sent])
      expect(page.url).to eq("#{@base}#{sent}")
    end
  end

  it 'keeps the fragment out of the request and in url' do
    serve
    page = MetaInspector.new("#{@base}/page?b=2&a=1#section", normalize_url: false)
    expect(@targets).to eq(['/page?b=2&a=1'])
    expect(page.url).to eq("#{@base}/page?b=2&a=1#section")
  end

  it 'sends the same query in the HEAD request' do
    serve
    MetaInspector.new("#{@base}/?tag=x&tag=y", head_first: true)
    expect(@targets).to eq(['/?tag=x&tag=y', '/?tag=x&tag=y'])
  end

  it 'follows redirects from and to URLs with queries' do
    serve('/old' => [301, { 'Location' => '/new?tag=x&tag=y' }, ''])
    page = MetaInspector.new("#{@base}/old?b=2&a=1", normalize_url: false)
    expect(@targets).to eq(['/old?b=2&a=1', '/new?tag=x&tag=y'])
    expect(page.url).to eq("#{@base}/new?tag=x&tag=y")
  end

  it 'requests image URLs with their query as given' do
    png = "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [37, 29].pack('NN') + "\x08\x02\x00\x00\x00".b
    serve('/image' => [200, { 'Content-Type' => 'image/png' }, png])
    page = MetaInspector.new('http://page.example/', document: %(<img src="#{@base}/image?w=2&h=1&w=3">))
    expect(page.images.with_size).to eq([["#{@base}/image?w=2&h=1&w=3", 37, 29]])
    expect(@targets).to eq(['/image?w=2&h=1&w=3'])
  end

  it 'uses a params encoder given in faraday_options' do
    serve
    MetaInspector.new("#{@base}/?b=2&a=1", faraday_options: { request: { params_encoder: Faraday::FlatParamsEncoder } })
    expect(@targets).to eq(['/?a=1&b=2'])
  end
end
