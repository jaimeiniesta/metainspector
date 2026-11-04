require 'spec_helper'

describe MetaInspector, 'head_first option' do
  let(:page_url) { 'http://example.com/head-first' }
  let(:html) { '<html><head><title>Downloaded page</title></head></html>' }
  let!(:get_request) do
    stub_request(:get, page_url).to_return(body: html, headers: { 'Content-Type' => 'text/html' })
  end

  it 'does not send HEAD by default' do
    expect(MetaInspector.new(page_url).title).to eq('Downloaded page')

    expect(a_request(:head, page_url)).not_to have_been_made
    expect(get_request).to have_been_requested.once
  end

  it 'does not send HEAD when explicitly disabled' do
    expect(MetaInspector.new(page_url, head_first: false).title).to eq('Downloaded page')

    expect(a_request(:head, page_url)).not_to have_been_made
  end

  it 'sends HEAD before GET for HTML and exposes the GET response' do
    requests = []
    head_request = stub_request(:head, page_url).to_return do
      requests << :head
      { headers: { 'Content-Type' => 'text/html; charset=UTF-8', 'X-Response' => 'head' } }
    end
    stub_request(:get, page_url).to_return do
      requests << :get
      { body: html, headers: { 'Content-Type' => 'text/html', 'X-Response' => 'get' } }
    end

    page = MetaInspector.new(page_url, head_first: true)

    expect(page.title).to eq('Downloaded page')
    expect(page.content_type).to eq('text/html')
    expect(page.response.headers['x-response']).to eq('get')
    expect(page.to_s).to eq(html)
    expect(head_request).to have_been_requested.once
    expect(requests).to eq([:head, :get])
  end

  it 'rejects non-HTML content without sending GET' do
    head_request = stub_request(:head, page_url)
      .to_return(headers: { 'Content-Type' => 'application/pdf; version=1.7' })

    expect do
      MetaInspector.new(page_url, head_first: true)
    end.to raise_error(MetaInspector::NonHtmlError,
      'The url provided contains application/pdf content instead of text/html content')

    expect(head_request).to have_been_requested.once
    expect(get_request).not_to have_been_requested
  end

  it 'downloads non-HTML content when explicitly allowed' do
    head_request = stub_request(:head, page_url).to_return(headers: { 'Content-Type' => 'text/plain' })
    stub_request(:get, page_url).to_return(body: 'Plain text', headers: { 'Content-Type' => 'text/plain' })

    page = MetaInspector.new(page_url, head_first: true, allow_non_html_content: true)

    expect(page.to_s).to eq('Plain text')
    expect(page.content_type).to eq('text/plain')
    expect(head_request).to have_been_requested.once
    expect(get_request).to have_been_requested.once
  end

  it 'continues to GET when HEAD has no content type' do
    head_request = stub_request(:head, page_url).to_return(status: 200)

    expect(MetaInspector.new(page_url, head_first: true).title).to eq('Downloaded page')

    expect(head_request).to have_been_requested.once
    expect(get_request).to have_been_requested.once
  end

  [403, 404, 405, 501].each do |status|
    it "continues to GET when HEAD returns #{status}" do
      head_request = stub_request(:head, page_url)
        .to_return(status: status, headers: { 'Content-Type' => 'text/plain' })

      expect(MetaInspector.new(page_url, head_first: true).title).to eq('Downloaded page')

      expect(head_request).to have_been_requested.once
      expect(get_request).to have_been_requested.once
    end
  end

  it 'still rejects a non-HTML GET response when HEAD reports HTML' do
    head_request = stub_request(:head, page_url).to_return(headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, page_url).to_return(headers: { 'Content-Type' => 'application/pdf' })

    expect do
      MetaInspector.new(page_url, head_first: true)
    end.to raise_error(MetaInspector::NonHtmlError)

    expect(head_request).to have_been_requested.once
    expect(get_request).to have_been_requested.once
  end

  it 'does not send requests for a supplied document' do
    expect(MetaInspector.new(page_url, head_first: true, document: html).title).to eq('Downloaded page')

    expect(a_request(:head, page_url)).not_to have_been_made
    expect(get_request).not_to have_been_requested
  end

  it 'sends custom headers on both requests' do
    headers = { 'User-Agent' => 'Custom agent', 'Authorization' => 'Bearer test-token' }
    head_request = stub_request(:head, page_url).with(headers: headers)
      .to_return(headers: { 'Content-Type' => 'text/html' })
    get_with_headers = stub_request(:get, page_url).with(headers: headers).to_return(body: html)

    expect(MetaInspector.new(page_url, head_first: true, headers: headers).title).to eq('Downloaded page')

    expect(head_request).to have_been_requested.once
    expect(get_with_headers).to have_been_requested.once
  end

  it 'follows HEAD redirects to reject non-HTML content before GET' do
    target = 'http://example.com/large.pdf'
    stub_request(:head, page_url).to_return(status: 302, headers: { 'Location' => target })
    target_request = stub_request(:head, target).to_return(headers: { 'Content-Type' => 'application/pdf' })

    expect do
      MetaInspector.new(page_url, head_first: true)
    end.to raise_error(MetaInspector::NonHtmlError)

    expect(target_request).to have_been_requested.once
    expect(a_request(:get, /example.com/)).not_to have_been_made
  end

  it 'follows GET redirects independently of HEAD and exposes the final GET URL' do
    head_target = 'http://example.com/head-target'
    get_target = 'http://example.com/get-target'
    head_request = stub_request(:head, page_url).to_return(status: 302, headers: { 'Location' => head_target })
    stub_request(:head, head_target).to_return(headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, page_url).to_return(status: 302, headers: { 'Location' => get_target })
    final_request = stub_request(:get, get_target).to_return(body: html, headers: { 'Content-Type' => 'text/html' })

    page = MetaInspector.new(page_url, head_first: true)

    expect(page.title).to eq('Downloaded page')
    expect(page.url).to eq(get_target)
    expect(head_request).to have_been_requested.once
    expect(final_request).to have_been_requested.once
    expect(a_request(:get, head_target)).not_to have_been_made
  end

  it 'does not follow HEAD redirects when redirections are disabled' do
    head_request = stub_request(:head, page_url)
      .to_return(status: 302, headers: { 'Location' => 'http://example.com/target', 'Content-Type' => 'text/plain' })

    page = MetaInspector.new(page_url, head_first: true, allow_redirections: false)

    expect(page.title).to eq('Downloaded page')
    expect(page.url).to eq(page_url)
    expect(head_request).to have_been_requested.once
    expect(a_request(:head, 'http://example.com/target')).not_to have_been_made
  end

  it 'keeps cookies from HEAD for the GET request' do
    head_request = stub_request(:head, page_url)
      .to_return(headers: { 'Content-Type' => 'text/html', 'Set-Cookie' => 'session=checked; path=/' })
    get_with_cookie = stub_request(:get, page_url).with(headers: { 'Cookie' => 'session=checked' }).to_return(body: html)

    expect(MetaInspector.new(page_url, head_first: true).title).to eq('Downloaded page')

    expect(head_request).to have_been_requested.once
    expect(get_with_cookie).to have_been_requested.once
  end

  it 'wraps HEAD timeouts without sending GET' do
    head_request = stub_request(:head, page_url).to_raise(Net::ReadTimeout)

    expect do
      MetaInspector.new(page_url, head_first: true, retries: 0)
    end.to raise_error(MetaInspector::TimeoutError)

    expect(head_request).to have_been_requested.once
    expect(get_request).not_to have_been_requested
  end

  it 'wraps HEAD connection failures without sending GET' do
    head_request = stub_request(:head, page_url).to_raise(Faraday::ConnectionFailed.new('connection failed'))

    expect do
      MetaInspector.new(page_url, head_first: true, retries: 0)
    end.to raise_error(MetaInspector::RequestError)

    expect(head_request).to have_been_requested.once
    expect(get_request).not_to have_been_requested
  end
end
