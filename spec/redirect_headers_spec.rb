require 'spec_helper'

RSpec.describe 'page redirect headers' do
  let(:initial) { 'https://app.example/start' }
  let(:headers) do
    {
      'authorization' => 'Bearer secret',
      'cookie' => 'session=secret',
      'proxy-authorization' => 'Basic secret',
      'x-api-key' => 'secret',
      'referer' => 'https://private.example/secret',
      'range' => 'bytes=0-100',
      'user-agent' => 'Policy app',
      'accept' => 'text/html',
      'accept-language' => 'en',
      'accept-encoding' => 'identity'
    }.freeze
  end
  let(:safe_headers) { headers.slice('user-agent', 'accept', 'accept-language', 'accept-encoding') }
  let(:html) { '<title>landing</title>' }

  def expect_safe_headers(request)
    expect(request.headers.keys).not_to include('Authorization', 'Cookie', 'Proxy-Authorization',
      'X-Api-Key', 'X-Faraday-Secret', 'Referer', 'Range')
    safe_headers.each { |key, value| expect(request.headers[key.split('-').map(&:capitalize).join('-')]).to eq(value) }
    true
  end

  [false, true].each do |head_first|
    [
      'https://other.example/landing',
      'http://app.example/landing',
      'https://sub.app.example/landing',
      'https://app.example:8443/landing',
      '//other.example/landing'
    ].each do |destination|
      it "strips credentials for #{destination} with head_first: #{head_first}" do
        target = URI.join(initial, destination).to_s
        methods = head_first ? [:head, :get] : [:get]
        methods.each do |method|
          stub_request(method, initial).with(headers: headers)
            .to_return(status: 302, headers: { 'Location' => destination })
          stub_request(method, target).with { |request| expect_safe_headers(request) }
            .to_return(body: html, headers: { 'Content-Type' => 'text/html' })
        end

        page = MetaInspector.new(initial, headers: headers, head_first: head_first,
          faraday_options: { headers: { 'X-Faraday-Secret' => 'secret' }.freeze }.freeze)

        expect(page.title).to eq('landing')
        expect(page.headers).to eq(headers)
        methods.each { |method| expect(a_request(method, target)).to have_been_made.once }
      end
    end
  end

  ['/landing', 'https://app.example:443/landing'].each do |destination|
    it "preserves custom headers for same-origin redirect #{destination}" do
      stub_request(:get, initial).with(headers: headers)
        .to_return(status: 302, headers: { 'Location' => destination, 'Set-Cookie' => 'server=value; Path=/; Secure' })
      stub_request(:get, 'https://app.example/landing').with do |request|
        expect(request.headers['Cookie']).to include('server=value', 'session=secret')
        expect(request.headers['X-Api-Key']).to eq('secret')
        expect(request.headers['Authorization']).to eq('Bearer secret')
        true
      end.to_return(body: html)

      expect(MetaInspector.new(initial, headers: headers).title).to eq('landing')
    end
  end

  it 'applies the policy after redirect callbacks change the destination and headers' do
    stub_request(:get, initial).to_return(status: 302, headers: { 'Location' => '/landing' })
    stub_request(:get, 'https://other.example/landing').with { |request| expect_safe_headers(request) }
      .to_return(body: html)
    callback = lambda do |_, following|
      following.url = URI('https://other.example/landing')
      following.request_headers['X-Api-Key'] = 'callback-secret'
    end

    page = MetaInspector.new(initial, headers: headers,
      faraday_options: { redirect: { callback: callback, clear_authorization_header: false }.freeze }.freeze)

    expect(page.title).to eq('landing')
  end

  it 'keeps credentials stripped throughout a redirect chain' do
    stub_request(:get, initial).to_return(status: 302, headers: { 'Location' => 'https://other.example/step' })
    stub_request(:get, 'https://other.example/step').with { |request| expect_safe_headers(request) }
      .to_return(status: 302, headers: { 'Location' => '/landing' })
    stub_request(:get, 'https://other.example/landing').with { |request| expect_safe_headers(request) }
      .to_return(status: 302, headers: { 'Location' => 'https://app.example/landing' })
    stub_request(:get, 'https://app.example/landing').with { |request| expect_safe_headers(request) }
      .to_return(body: html)

    expect(MetaInspector.new(initial, headers: headers).title).to eq('landing')
  end

  it 'does not reintroduce the initial credentials when fetching images on the redirected page' do
    png = "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [37, 29].pack('NN') + "\x08\x02\x00\x00\x00".b
    stub_request(:get, initial).to_return(status: 302, headers: { 'Location' => 'https://other.example/landing' })
    stub_request(:get, 'https://other.example/landing')
      .to_return(body: '<img src="/image.png">', headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, 'https://other.example/image.png').with do |request|
      expect(request.headers.keys).not_to include('Authorization', 'Cookie', 'Proxy-Authorization',
        'X-Api-Key', 'X-Faraday-Secret', 'Referer')
      expect(request.headers['Range']).to eq('bytes=0-262143')
      true
    end.to_return(body: png)

    page = MetaInspector.new(initial, headers: headers,
      faraday_options: { headers: { 'X-Faraday-Secret' => 'secret' } })

    expect(page.images.with_size).to eq([['https://other.example/image.png', 37, 29]])
  end

  it 'can reuse caller headers across independent page requests' do
    stub_request(:get, initial).with(headers: headers)
      .to_return(status: 302, headers: { 'Location' => 'https://other.example/landing' })
    stub_request(:get, 'https://other.example/landing').with { |request| expect_safe_headers(request) }
      .to_return(body: html)

    2.times { expect(MetaInspector.new(initial, headers: headers).title).to eq('landing') }

    expect(a_request(:get, initial).with(headers: headers)).to have_been_made.twice
  end

  it 'preserves image header protection when an image points back to the initial page origin' do
    png = "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [37, 29].pack('NN') + "\x08\x02\x00\x00\x00".b
    stub_request(:get, initial).to_return(status: 302, headers: { 'Location' => 'https://other.example/landing' })
    stub_request(:get, 'https://other.example/landing')
      .to_return(body: '<img src="https://app.example/image.png">', headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, 'https://app.example/image.png').with do |request|
      expect(request.headers.keys).not_to include('Authorization', 'Cookie', 'Proxy-Authorization', 'X-Api-Key')
      expect(request.headers['Referer']).to eq('https://other.example/')
      true
    end.to_return(body: png)

    page = MetaInspector.new(initial, headers: headers)

    expect(page.images.with_size).to eq([['https://app.example/image.png', 37, 29]])
  end
end
