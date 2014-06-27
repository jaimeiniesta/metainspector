# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector::Document do
  describe 'passing the contents of the document as html' do
    before(:each) do
      @m = MetaInspector::Document.new('http://cnn.com/', :document => "<html><head><title>Hello From Passed Html</title><a href='/hello'>Hello link</a></head><body></body></html>")
    end

    it "should get correct links when the url html is passed as an option" do
      @m.links.should == ["http://cnn.com/hello"]
    end

    it "should get the title" do
      @m.title.should == "Hello From Passed Html"
    end
  end

  it "should return a String as to_s" do
    MetaInspector::Document.new('http://pagerankalert.com').to_s.class.should == String
  end

  it "should return a Hash with all the values set" do
    @m = MetaInspector::Document.new('http://pagerankalert.com')
    @m.to_hash.should == {
                            "url"             =>"http://pagerankalert.com/",
                            "title"           =>"PageRankAlert.com :: Track your PageRank changes & receive alerts",
                            "favicon"         =>"http://pagerankalert.com/src/favicon.ico",
                            "links"           => ["http://pagerankalert.com/",
                                                  "http://pagerankalert.com/es?language=es",
                                                  "http://pagerankalert.com/users/sign_up",
                                                  "http://pagerankalert.com/users/sign_in",
                                                  "mailto:pagerankalert@gmail.com",
                                                  "http://pagerankalert.posterous.com/",
                                                  "http://twitter.com/pagerankalert",
                                                  "http://twitter.com/share"],
                            "internal_links"  => ["http://pagerankalert.com/",
                                                  "http://pagerankalert.com/es?language=es",
                                                  "http://pagerankalert.com/users/sign_up",
                                                  "http://pagerankalert.com/users/sign_in"],
                            "external_links"  => ["mailto:pagerankalert@gmail.com",
                                                  "http://pagerankalert.posterous.com/",
                                                  "http://twitter.com/pagerankalert",
                                                  "http://twitter.com/share"],
                            "images"          => ["http://pagerankalert.com/images/pagerank_alert.png?1305794559"],
                            "charset"         => "utf-8",
                            "feed"            => "http://feeds.feedburner.com/PageRankAlert",
                            "content_type"    =>"text/html",
                            "meta_tags"       => { "name" => { "description" => ["Track your PageRank(TM) changes and receive alerts by email"],
                                                               "keywords"    => ["pagerank, seo, optimization, google"], "robots"=>["all,follow"],
                                                               "csrf-param"  => ["authenticity_token"],
                                                               "csrf-token"  => ["iW1/w+R8zrtDkhOlivkLZ793BN04Kr3X/pS+ixObHsE="] },
                                                   "http-equiv" => {},
                                                   "property"   => {},
                                                   "charset"    => ["utf-8"] }
                         }
  end

  describe 'exception handling' do
    let(:logger) { MetaInspector::ExceptionLog.new }

    it "should parse images when parse_html_content_type_only is not specified" do
      logger.should_not receive(:<<)

      image_url = MetaInspector::Document.new('http://pagerankalert.com/image.png', exception_log: logger)
      image_url.title
    end

    it "should parse images when parse_html_content_type_only is false" do
      logger.should_not receive(:<<)

      image_url = MetaInspector::Document.new('http://pagerankalert.com/image.png', html_content_only: false, exception_log: logger)
      image_url.title
    end

    it "should handle errors when content is image/jpeg and html_content_type_only is true" do
      logger.should_receive(:<<).with(an_instance_of(RuntimeError))

      image_url = MetaInspector::Document.new('http://pagerankalert.com/image.png', html_content_only: true, exception_log: logger)

      image_url.title
    end

    it "should handle errors when content is not text/html and html_content_type_only is true" do
      logger.should_receive(:<<).with(an_instance_of(RuntimeError))

      tar_url = MetaInspector::Document.new('http://pagerankalert.com/file.tar.gz', html_content_only: true, exception_log: logger)

      tar_url.title
    end
  end

  describe 'headers' do
    it "should include default headers" do
      url     = 'http://example.com/headers'
      request = double('Request', base_uri: url)
      expected_headers = {'User-Agent' => "MetaInspector/#{MetaInspector::VERSION} (+https://github.com/jaimeiniesta/metainspector)"}

      MetaInspector::Request.any_instance.should_receive(:open)
                                         .with(url, expected_headers)
                                         .and_return(request)

      MetaInspector::Document.new(url)
    end

    it "should include passed headers on the request" do
      url     = 'http://example.com/headers'
      headers = {'User-Agent' => 'Mozilla', 'Referer' => 'https://github.com/'}
      request = double('Request', base_uri: url)

      MetaInspector::Request.any_instance.should_receive(:open)
                                         .with(url, headers)
                                         .and_return(request)

      MetaInspector::Document.new(url, headers: headers)
    end
  end
end
