require 'spec_helper'

describe MetaInspector::Document do
  describe 'passing the contents of the document as html' do
    let(:doc) { MetaInspector::Document.new('http://cnn.com/', :document => "<html><head><title>Hello From Passed Html</title><a href='/hello'>Hello link</a></head><body></body></html>") }

    it "should get correct links when the url html is passed as an option" do
      expect(doc.links.internal).to eq(["http://cnn.com/hello"])
    end

    it "should get the title" do
      expect(doc.title).to eq("Hello From Passed Html")
    end
  end

  it "should return a String as to_s" do
    expect(MetaInspector::Document.new('http://pagerankalert.com').to_s.class).to eq(String)
  end

  it "should return a Hash with all the values set" do
    doc = MetaInspector::Document.new('http://pagerankalert.com')
    expect(doc.to_hash).to eq({
                            "url"             => "http://pagerankalert.com/",
                            "scheme"          => "http",
                            "host"            => "pagerankalert.com",
                            "root_url"        => "http://pagerankalert.com/",
                            "title"           => "PageRankAlert.com :: Track your PageRank changes & receive alerts",
                            "best_title"      => "PageRankAlert.com :: Track your PageRank changes & receive alerts",
                            "description"     => "Track your PageRank(TM) changes and receive alerts by email",
                            "favicon"         => "http://pagerankalert.com/src/favicon.ico",
                            "links"           => {
                                                    'internal' => ["http://pagerankalert.com/",
                                                                   "http://pagerankalert.com/es?language=es",
                                                                   "http://pagerankalert.com/users/sign_up",
                                                                   "http://pagerankalert.com/users/sign_in"],
                                                    'external' => ["http://pagerankalert.posterous.com/",
                                                                   "http://twitter.com/pagerankalert",
                                                                   "http://twitter.com/share"],
                                                    'non_http' => ["mailto:pagerankalert@gmail.com"]
                                                  },
                            "images"          => ["http://pagerankalert.com/images/pagerank_alert.png?1305794559"],
                            "charset"         => "utf-8",
                            "language"        => "en-US",
                            "feed"            => "http://feeds.feedburner.com/PageRankAlert",
                            "content_type"    => "text/html",
                            "meta_tags"       => {
                                                   "name" => {
                                                               "description" => ["Track your PageRank(TM) changes and receive alerts by email"],
                                                               "keywords"    => ["pagerank, seo, optimization, google"], "robots"=>["all,follow"],
                                                               "csrf-param"  => ["authenticity_token"],
                                                               "csrf-token"  => ["iW1/w+R8zrtDkhOlivkLZ793BN04Kr3X/pS+ixObHsE="]
                                                             },
                                                   "http-equiv" => {},
                                                   "property"   => {},
                                                   "language"   => ["en-US"],
                                                   "charset"    => ["utf-8"]
                                                 },
                            "response"        => {
                                                   "status"  => 200,
                                                   "headers" => {
                                                                  "server" => "nginx/0.7.67",
                                                                  "date"=>"Mon, 30 May 2011 09:45:42 GMT",
                                                                  "content-type" => "text/html; charset=utf-8",
                                                                  "connection" => "keep-alive",
                                                                  "etag" => "\"d0534cf7ad7d7a7fb737fe4ad99b0fd1\"",
                                                                  "x-ua-compatible" => "IE=Edge,chrome=1",
                                                                  "x-runtime" => "0.031274",
                                                                  "set-cookie" => "_session_id=33575f7694b4492af4c4e282d62a7127; path=/; HttpOnly",
                                                                  "cache-control" => "max-age=0, private, must-revalidate",
                                                                  "content-length" => "6690",
                                                                  "x-varnish" => "2167295052",
                                                                  "age" => "0",
                                                                  "via" => "1.1 varnish"
                                                                }
                                                 }
                         })
  end

  describe 'exception handling' do
    let(:logger) { MetaInspector::ExceptionLog.new }

    it "should parse images when parse_html_content_type_only is not specified" do
      expect(logger).not_to receive(:<<)

      image_url = MetaInspector::Document.new('http://pagerankalert.com/image.png', exception_log: logger)
      image_url.title
    end

    it "should parse images when parse_html_content_type_only is false" do
      expect(logger).not_to receive(:<<)

      image_url = MetaInspector::Document.new('http://pagerankalert.com/image.png', html_content_only: false, exception_log: logger)
      image_url.title
    end

    it "should handle errors when content is image/jpeg and html_content_type_only is true" do
      expect(logger).to receive(:<<).with(an_instance_of(RuntimeError))

      image_url = MetaInspector::Document.new('http://pagerankalert.com/image.png', html_content_only: true, exception_log: logger)

      image_url.title
    end

    it "should handle errors when content is not text/html and html_content_type_only is true" do
      expect(logger).to receive(:<<).with(an_instance_of(RuntimeError))

      tar_url = MetaInspector::Document.new('http://pagerankalert.com/file.tar.gz', html_content_only: true, exception_log: logger)

      tar_url.title
    end

    context 'when a warn_level of :store is passed in' do
      before do
        @bad_request = MetaInspector::Document.new('http://pagerankalert.com/image.png', html_content_only: true, warn_level: :store)
        @bad_request.title
      end

      it 'stores the exceptions' do
        expect(@bad_request.exceptions).not_to be_empty
      end

      it 'makes ok? to return false' do
        expect(@bad_request).not_to be_ok
      end
    end

    context 'when a warn_level of :warn is passed in' do
      before do
        $stderr = StringIO.new
      end

      after do
        $stderr = STDERR
      end

      it 'warns on STDERR' do
        bad_request = MetaInspector::Document.new('http://pagerankalert.com/image.png', html_content_only: true, warn_level: :warn)
        bad_request.title

        $stderr.rewind
        expect($stderr.string.chomp).to eq("The url provided contains image/png content instead of text/html content")
      end

      it 'does not raise an exception' do
        expect {
          bad_request = MetaInspector::Document.new('http://pagerankalert.com/image.png', html_content_only: true, warn_level: :warn)
          bad_request.title
        }.to_not raise_exception
      end

      it 'does not store exceptions' do
        bad_request = MetaInspector::Document.new('http://pagerankalert.com/image.png', html_content_only: true, warn_level: :warn)
        bad_request.title

        expect( bad_request.exceptions ).to be_empty
      end
    end
  end

  describe 'headers' do
    it "should include default headers" do
      url = "http://pagerankalert.com/"
      expected_headers = {'User-Agent' => "MetaInspector/#{MetaInspector::VERSION} (+https://github.com/jaimeiniesta/metainspector)"}

      headers = {}
      expect(headers).to receive(:merge!).with(expected_headers)
      allow_any_instance_of(Faraday::Connection).to receive(:headers){headers}
      MetaInspector::Document.new(url)
    end

    it "should include passed headers on the request" do
      url = "http://pagerankalert.com/"
      headers = {'User-Agent' => 'Mozilla', 'Referer' => 'https://github.com/'}

      headers = {}
      expect(headers).to receive(:merge!).with(headers)
      allow_any_instance_of(Faraday::Connection).to receive(:headers){headers}
      MetaInspector::Document.new(url, headers: headers)
    end
  end

  describe 'url normalization' do
    it 'should normalize by default' do
      expect(MetaInspector.new('http://example.com/%EF%BD%9E').url).to eq('http://example.com/~')
    end

    it 'should not normalize if the normalize_url option is false' do
      expect(MetaInspector.new('http://example.com/%EF%BD%9E', normalize_url: false).url).to eq('http://example.com/%EF%BD%9E')
    end
  end
end
