require 'spec_helper'

RSpec.describe 'outbound URL policy' do
  let(:url) { 'https://public.example/page' }
  let(:image_url) { 'https://public.example/image.png' }
  let(:html) { '<img src="/image.png">' }
  let(:png) { "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [37, 29].pack('NN') + "\x08\x02\x00\x00\x00".b }

  before do
    stub_request(:get, url).to_return(body: html, headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, image_url).to_return(body: png, headers: { 'Content-Type' => 'image/png; charset=UTF-8' })
  end

  [false, nil].each do |result|
    it "blocks the initial GET when the filter returns #{result.inspect}" do
      expect { MetaInspector.new(url, url_filter: ->(_) { result }) }.to raise_error(MetaInspector::RequestError)
      expect(a_request(:get, url)).not_to have_been_made
    end
  end

  it 'passes a standard Ruby URI and permits truthy results' do
    seen = []
    page = MetaInspector.new(url, url_filter: ->(uri) { seen << uri; :allowed })
    expect(page.images.with_size).to eq([[image_url, 37, 29]])
    expect(seen.map(&:to_s)).to eq([url, image_url])
    expect(seen).to all(be_a(URI::HTTP))
  end

  it 'does not permit mutations of the filter URI to change the request host' do
    filter = ->(uri) { uri.host.replace('internal.example'); true }
    expect(MetaInspector.new(url, url_filter: filter).url).to eq(url)
    expect(a_request(:get, 'https://internal.example/page')).not_to have_been_made
  end

  [RuntimeError, Faraday::TimeoutError, Faraday::ConnectionFailed, URI::InvalidURIError, Timeout::Error].each do |error_class|
    [:page, :image].each do |target|
      it "preserves a filter's #{error_class} on a #{target}" do
        error = error_class.new('policy failed')
        filter = ->(_) { raise error }
        expect do
          if target == :page
            MetaInspector.new(url, url_filter: filter)
          else
            MetaInspector.new(url, document: html, url_filter: filter).images.with_size
          end
        end.to raise_error { |actual| expect(actual).to equal(error) }
      end
    end
  end

  it 'checks HEAD and checks GET again after HEAD' do
    stub_request(:head, url).to_return(headers: { 'Content-Type' => 'text/html' })
    calls = 0
    expect do
      MetaInspector.new(url, head_first: true, url_filter: ->(_) { calls += 1; calls == 1 })
    end.to raise_error(MetaInspector::RequestError)
    expect(a_request(:head, url)).to have_been_made.once
    expect(a_request(:get, url)).not_to have_been_made
  end

  it 'blocks HEAD before making a request' do
    expect { MetaInspector.new(url, head_first: true, url_filter: ->(_) { false }) }.to raise_error(MetaInspector::RequestError)
    expect(a_request(:head, url)).not_to have_been_made
  end

  [:head, :get].each do |method|
    it "checks every #{method} redirect after the existing redirects-only callback" do
      urls = [url, 'https://public.example/next', 'https://internal.example/private']
      urls.each_cons(2) { |from, to| stub_request(method, from).to_return(status: 302, headers: { 'Location' => to }) }
      seen = []
      redirects = []
      callback = ->(previous, following) { redirects << [previous.url.to_s, following.url.to_s] }
      filter = ->(uri) { seen << uri.to_s; uri.host == 'public.example' }
      expect do
        MetaInspector.new(url, head_first: method == :head, url_filter: filter,
                          faraday_options: { redirect: { callback: callback }.freeze }.freeze)
      end.to raise_error(MetaInspector::RequestError)
      expect(seen).to eq(urls)
      expect(redirects).to eq(urls.each_cons(2).to_a)
      expect(a_request(method, urls.last)).not_to have_been_made
    end
  end

  it 'validates redirect destinations changed by the existing callback' do
    stub_request(:get, url).to_return(status: 302, headers: { 'Location' => '/next' })
    callback = ->(_, following) { following.url.host = 'internal.example' }
    expect do
      MetaInspector.new(url, url_filter: ->(uri) { uri.host == 'public.example' }, faraday_options: { redirect: { callback: callback } })
    end.to raise_error(MetaInspector::RequestError)
    expect(a_request(:get, 'https://internal.example/next')).not_to have_been_made
  end

  it 'runs policy before a cached response can be reused' do
    cache = Class.new(Hash) do
      def read(key); self[key]; end
      def write(key, value); self[key] = value; end
    end.new
    stub_request(:get, url).to_return(body: html, headers: { 'Cache-Control' => 'public, max-age=3600' })
    permitted = true
    options = { url_filter: ->(_) { permitted }, faraday_options: { faraday_http_cache: { store: cache } } }
    MetaInspector.new(url, options)
    expect(cache).not_to be_empty
    permitted = false
    expect { MetaInspector.new(url, options) }.to raise_error(MetaInspector::RequestError)
    expect(a_request(:get, url)).to have_been_made.once
  end

  it 'blocks images from inline HTML before downloading' do
    page = MetaInspector.new(url, document: html, url_filter: ->(_) { false })
    expect { page.images.with_size }.to raise_error(MetaInspector::RequestError)
    expect(a_request(:get, url)).not_to have_been_made
    expect(a_request(:get, image_url)).not_to have_been_made
  end

  it 'checks every image redirect' do
    stub_request(:get, image_url).to_return(status: 302, headers: { 'Location' => '/second.png' })
    stub_request(:get, 'https://public.example/second.png').to_return(status: 302, headers: { 'Location' => 'http://internal.example/private' })
    page = MetaInspector.new(url, document: html, url_filter: ->(uri) { uri.host == 'public.example' })
    expect { page.images.with_size }.to raise_error(MetaInspector::RequestError)
    expect(a_request(:get, 'http://internal.example/private')).not_to have_been_made
  end

  ['file:///etc/passwd', 'ftp://files.example/image', 'data:image/png;base64,AAAA', 'ftp://files.example/http://public.example/'].each do |other|
    it "rejects non-HTTP network URL #{other}" do
      expect { MetaInspector.new(other) }.to raise_error(MetaInspector::RequestError)
      page = MetaInspector.new(url, document: %(<img src="#{other}">))
      expect { page.images.with_size }.to raise_error(MetaInspector::RequestError)
    end
  end

  it 'rejects non-HTTP redirect schemes' do
    stub_request(:get, url).to_return(status: 302, headers: { 'Location' => 'file:///etc/passwd' })
    expect { MetaInspector.new(url) }.to raise_error(MetaInspector::RequestError)
  end

  it 'uses the page headers and redirects-only callback for images' do
    headers = { 'Authorization' => 'Bearer test', 'User-Agent' => 'Policy app' }.freeze
    stub_request(:get, image_url).with(headers: headers).to_return(status: 302, headers: { 'Location' => '/final.png' })
    stub_request(:get, 'https://public.example/final.png').with(headers: headers).to_return(body: png)
    redirects = []
    page = MetaInspector.new(url, document: html, headers: headers,
      faraday_options: { redirect: { callback: ->(old, following) { redirects << [old.url.to_s, following.url.to_s] } } })
    expect(page.images.with_size).to eq([[image_url, 37, 29]])
    expect(redirects).to eq([[image_url, 'https://public.example/final.png']])
  end

  it 'does not follow image redirects when disabled' do
    stub_request(:get, image_url).to_return(status: 302, headers: { 'Location' => '/final.png' })
    page = MetaInspector.new(url, document: html, allow_redirections: false)
    expect(page.images.with_size).to eq([[image_url, 0, 0]])
    expect(a_request(:get, 'https://public.example/final.png')).not_to have_been_made
  end

  it 'uses binary IO rather than a URL for image parsing' do
    expect(FastImage).to receive(:size).with(an_instance_of(StringIO)).and_call_original
    expect(MetaInspector.new(url, document: html).images.with_size).to eq([[image_url, 37, 29]])
  end

  [:to_timeout, :connection_failure, :unparseable].each do |failure|
    it "returns zero dimensions for image #{failure}" do
      request = stub_request(:get, image_url)
      case failure
      when :to_timeout then request.to_timeout
      when :connection_failure then request.to_raise(Faraday::ConnectionFailed)
      when :unparseable then request.to_return(body: 'not an image')
      end
      expect(MetaInspector.new(url, document: html).images.with_size).to eq([[image_url, 0, 0]])
      expect(request).to have_been_requested.once
    end
  end
  it 'rejects a non-callable filter even for inline HTML' do
    expect { MetaInspector.new(url, document: html, url_filter: false) }.to raise_error(ArgumentError, /url_filter/)
  end

  [
    'https://other.example/image.png',
    'http://public.example/image.png',
    'https://public.example:8443/image.png'
  ].each do |external|
    it "does not send custom page headers to a different image origin #{external}" do
      secret_headers = { 'Authorization' => 'Bearer secret', 'Cookie' => 'session=secret', 'X-Api-Key' => 'secret' }
      stub_request(:get, external).with do |request|
        expect(request.headers.keys).not_to include('Authorization', 'Cookie', 'X-Api-Key')
        true
      end.to_return(body: png)
      page = MetaInspector.new(url, document: %(<img src="#{external}">),
        headers: secret_headers.merge('User-Agent' => 'Policy app'),
        faraday_options: { headers: { 'X-Faraday-Secret' => 'secret' } })
      expect(page.images.with_size).to eq([[external, 37, 29]])
      expect(a_request(:get, external).with { |r| r.headers.key?('X-Faraday-Secret') }).not_to have_been_made
    end
  end

  it 'retains custom headers on the page origin and strips them on image redirects' do
    secrets = { 'Authorization' => 'Bearer secret', 'Cookie' => 'session=secret', 'X-Api-Key' => 'secret' }
    external = 'https://other.example/image.png'
    stub_request(:get, image_url).with(headers: secrets).to_return(status: 302, headers: { 'Location' => external })
    stub_request(:get, external).with do |request|
      expect(request.headers.keys).not_to include('Authorization', 'Cookie', 'X-Api-Key')
      true
    end.to_return(body: png)
    page = MetaInspector.new(url, document: html, headers: secrets)
    expect(page.images.with_size).to eq([[image_url, 37, 29]])
  end

end
