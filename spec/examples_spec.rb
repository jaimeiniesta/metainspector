require 'spec_helper'
require 'stringio'
require 'json'

RSpec.describe 'runnable examples' do
  def run_example(name, *args)
    stub_const('ARGV', args)
    original_stdout = $stdout
    $stdout = StringIO.new
    load(File.expand_path("../examples/#{name}.rb", __dir__), true)
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  def stub_page(path, html, status: 200)
    stub_request(:get, "http://site.example#{path}").to_return(
      status: status, headers: { 'Content-Type' => 'text/html' }, body: html
    )
  end

  def stub_image(path, fixture)
    stub_request(:get, "http://site.example#{path}").to_return(fixture_file(fixture))
  end

  describe 'basic_scraping' do
    it 'prints title and links' do
      output = run_example('basic_scraping', 'http://example.com')
      expect(output).to include('TITLE: An example page', 'internal links found')
    end

    it 'runs from the examples directory' do
      Dir.chdir(File.expand_path('../examples', __dir__)) do
        expect(run_example('basic_scraping', 'http://example.com')).to include('TITLE: An example page')
      end
    end

    it 'prints the page hash as JSON' do
      output = Dir.chdir(File.expand_path('../examples', __dir__)) do
        run_example('basic_scraping', 'http://example.com')
      end
      expect(JSON.parse(output.split("to_hash...\n", 2).last)).to include('title' => 'An example page')
    end
  end

  describe 'spider' do
    it 'visits every internal page once' do
      stub_page('/', '<a href="/a">A</a><a href="/b">B</a>')
      stub_page('/a', '<a href="/">Home</a>')
      stub_page('/b', '<title>B</title>')

      output = run_example('spider', 'http://site.example/')
      expect(output.lines.grep(/^VISITED: /).map(&:strip)).to contain_exactly(
        'VISITED: http://site.example/', 'VISITED: http://site.example/a', 'VISITED: http://site.example/b'
      )
    end
  end

  describe 'link_checker' do
    it 'reports broken links with their origin' do
      stub_page('/', '<a href="/ok">OK</a><a href="/missing">Missing</a>')
      stub_page('/ok', '<title>OK</title>')
      stub_page('/missing', '<title>Missing</title>', status: 404)

      output = run_example('link_checker', 'http://site.example/')
      expect(output).to include('1 broken links found.', "http://site.example/missing linked from\n - http://site.example/")
    end
  end

  describe 'faraday_redirect_options' do
    it 'rejects an untrusted initial URL before making a request' do
      target = 'http://127.0.0.1/'
      stub_request(:get, target).to_return(status: 200)

      expect { run_example('faraday_redirect_options', target) }
        .to output(/Request blocked by url_filter/).to_stderr
      expect(a_request(:get, target)).not_to have_been_made
    end

    it 'rejects an untrusted redirect before making a request to its destination' do
      target = 'http://127.0.0.1/'
      stub_request(:get, 'https://example.com/').to_return(status: 302, headers: { 'Location' => target })
      stub_request(:get, target).to_return(status: 200)
      stdout = nil

      expect { stdout = run_example('faraday_redirect_options', 'https://example.com/') }
        .to output(/Request blocked by url_filter/).to_stderr
      expect(stdout).to include('Redirect:')
      expect(a_request(:get, target)).not_to have_been_made
    end

    it 'follows redirects to allowed HTTPS hosts' do
      stub_request(:get, 'https://example.com/').to_return(status: 302, headers: { 'Location' => 'https://www.example.com/' })
      stub_request(:get, 'https://www.example.com/').to_return(status: 200,
        headers: { 'Content-Type' => 'text/html' }, body: '<title>Allowed page</title>')

      stdout = run_example('faraday_redirect_options', 'https://example.com/')
      expect(stdout).to match(/Redirect:.*Allowed page/m)
      expect(a_request(:get, 'https://www.example.com/')).to have_been_made.once
    end
  end
end
