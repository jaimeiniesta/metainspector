require 'spec_helper'

RSpec.describe 'the redirect options example' do
  def run_example(url)
    original_args = ARGV.dup
    ARGV.replace([url])
    load File.expand_path('../examples/faraday_redirect_options.rb', __dir__)
  ensure
    ARGV.replace(original_args)
  end

  it 'rejects an untrusted initial URL before making a request' do
    target = 'http://127.0.0.1/'
    stub_request(:get, target).to_return(status: 200)

    expect { run_example(target) }.to output(/Request blocked by url_filter/).to_stderr
    expect(a_request(:get, target)).not_to have_been_made
  end

  it 'rejects an untrusted redirect before making a request to its destination' do
    target = 'http://127.0.0.1/'
    stub_request(:get, 'https://example.com/').to_return(status: 302, headers: { 'Location' => target })
    stub_request(:get, target).to_return(status: 200)

    expect { run_example('https://example.com/') }.to output(/Request blocked by url_filter/).to_stderr
      .and output(/Redirect:/).to_stdout
    expect(a_request(:get, target)).not_to have_been_made
  end

  it 'follows redirects to allowed HTTPS hosts' do
    stub_request(:get, 'https://example.com/').to_return(status: 302, headers: { 'Location' => 'https://www.example.com/' })
    stub_request(:get, 'https://www.example.com/').to_return(status: 200,
      headers: { 'Content-Type' => 'text/html' }, body: '<title>Allowed page</title>')

    expect { run_example('https://example.com/') }.to output(/Redirect:.*Allowed page/m).to_stdout
    expect(a_request(:get, 'https://www.example.com/')).to have_been_made.once
  end
end
