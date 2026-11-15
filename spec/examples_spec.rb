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

  describe 'responsive_images' do
    it 'lists src and srcset candidates in document order' do
      stub_page('/', <<~HTML)
        <meta property="og:image" content="/og.png">
        <img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=" srcset="/medium.png 2x, /large.png 1000w">
        <picture><source srcset="/wide.webp"><img src="/fallback.png"></picture>
      HTML

      stdout = run_example('responsive_images', 'http://site.example/')
      expect(stdout.lines.grep(/^ ==> /).map(&:strip)).to eq([
        '==> data:image/gif;base64',
        '==> http://site.example/medium.png',
        '==> http://site.example/large.png',
        '==> http://site.example/wide.webp',
        '==> http://site.example/fallback.png'
      ])
      expect(stdout).to include('5 image candidates found', 'BEST: http://site.example/og.png')
      expect(stdout).not_to include('R0lGOD')
    end
  end

  describe 'image_details' do
    before do
      stub_page('/', '<img src="/100x100.jpg"><img src="/10x10.jpg">')
      stub_image('/100x100.jpg', '100x100.jpg.response')
      stub_image('/10x10.jpg', '10x10.jpg.response')
    end

    it 'prints dimensions, type and file size, largest first' do
      stub_page('/', '<img src="/10x10.jpg"><img src="/100x100.jpg">')
      stdout = run_example('image_details', 'http://site.example/')
      expect(stdout).to match(%r{100x100\.jpg 100x100 png, \d+ bytes.*10x10\.jpg 10x10 jpeg, \d+ bytes}m)
    end

    it 'respects the download limit' do
      stdout = run_example('image_details', 'http://site.example/', '1')
      expect(stdout).to include('http://site.example/100x100.jpg 100x100 png,',
                                'http://site.example/10x10.jpg 0x0 unknown type, unknown size')
      expect(a_request(:get, 'http://site.example/10x10.jpg')).not_to have_been_made
    end
  end

  describe 'image_validation' do
    before do
      stub_page('/', <<~HTML)
        <meta property="og:image" content="/missing.png">
        <img src="/10x10.jpg"><img src="/broken.png">
      HTML
      stub_image('/10x10.jpg', '10x10.jpg.response')
      stub_page('/broken.png', '<title>Not an image</title>')
      stub_page('/missing.png', '<title>Missing</title>', status: 404)
    end

    it 'reports validity and skips invalid images' do
      stdout = run_example('image_validation', 'http://site.example/')
      expect(stdout).to include('http://site.example/10x10.jpg: valid',
                                'http://site.example/broken.png: invalid',
                                'BEST: http://site.example/10x10.jpg')
      filtered = stdout.split("images remain after validation...\n", 2).last
      expect(filtered).to include(' ==> http://site.example/10x10.jpg')
      expect(filtered).not_to include('broken.png', 'missing.png')
      expect(a_request(:get, 'http://site.example/missing.png')).to have_been_made.once
    end

    it 'reports images beyond the download limit as not checked' do
      stdout = run_example('image_validation', 'http://site.example/', '1')
      expect(stdout).to include('http://site.example/10x10.jpg: valid',
                                'http://site.example/broken.png: not checked')
      expect(a_request(:get, 'http://site.example/broken.png')).not_to have_been_made
      expect(a_request(:get, 'http://site.example/missing.png')).not_to have_been_made
    end

    it 'can run twice without warnings' do
      expect {
        2.times { run_example('image_validation', 'http://site.example/') }
      }.not_to output.to_stderr
    end
  end

  describe 'iframes' do
    it 'prints iframe attributes without downloading embedded documents' do
      stub_page('/', '<iframe src=" /embed " title="Video" allowfullscreen></iframe><iframe></iframe>')

      stdout = run_example('iframes', 'http://site.example/')
      expect(stdout).to include('2 iframes found', ' ==> http://site.example/embed',
                                'title="Video"', 'allowfullscreen=""', ' ==> (no source)')
      expect(a_request(:get, 'http://site.example/embed')).not_to have_been_made
    end
  end

  describe 'html_size_limit' do
    before do
      stub_page('/', '<title>Small page</title>'.ljust(200))
    end

    it 'parses pages within the limit' do
      expect(run_example('html_size_limit', 'http://site.example/')).to include('TITLE: Small page')
    end

    it 'skips pages over the limit' do
      expect(run_example('html_size_limit', 'http://site.example/', '50')).to include('Skipped:')
    end
  end
end
