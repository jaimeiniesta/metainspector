# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector::Request do

  describe "read" do
    it "should return the content of the page" do
      page_request = MetaInspector::Request.new(url('http://pagerankalert.com'))

      page_request.read[0..14].should == "<!DOCTYPE html>"
    end
  end

  describe "response" do
    it "contains the response status" do
      page_request = MetaInspector::Request.new(url('http://example.com'))
      page_request.response.status.should == 200
    end

    it "contains the response headers" do
      page_request = MetaInspector::Request.new(url('http://example.com'))
      page_request.response.headers
        .should == {"server"=>"nginx/0.7.67", "date"=>"Fri, 18 Nov 2011 21:46:46 GMT",
                    "content-type"=>"text/html", "connection"=>"keep-alive",
                    "last-modified"=>"Mon, 14 Nov 2011 16:53:18 GMT",
                    "content-length"=>"4987", "x-varnish"=>"2000423390",
                    "age"=>"0", "via"=>"1.1 varnish"}
    end
  end

  describe "content_type" do
    it "should return the correct content type of the url for html pages" do
      page_request = MetaInspector::Request.new(url('http://pagerankalert.com'))

      page_request.content_type.should == "text/html"
    end

    it "should return the correct content type of the url for non html pages" do
      image_request = MetaInspector::Request.new(url('http://pagerankalert.com/image.png'))

      image_request.content_type.should == "image/png"
    end
  end

  describe 'exception handling' do
    let(:logger) { MetaInspector::ExceptionLog.new }

    before(:each) do
      FakeWeb.allow_net_connect = true
    end

    after(:each) do
      FakeWeb.allow_net_connect = false
    end

    it "should handle socket errors" do
      TCPSocket.stub(:open).and_raise(SocketError)
      logger.should receive(:<<).with(an_instance_of(Faraday::Error::ConnectionFailed))

      MetaInspector::Request.new(url('http://caca232dsdsaer3sdsd-asd343.org'), exception_log: logger)
    end
  end

  describe "retrying on timeouts" do
    let(:logger) { MetaInspector::ExceptionLog.new }
    subject do
      MetaInspector::Request.new(url('http://pagerankalert.com'),
                                 exception_log: logger, retries: 3)
     end

    context "when request never succeeds" do
      before{ Timeout.stub(:timeout).and_raise(Timeout::Error) }
      it "swallows all the timeout errors and raises MetaInspector::Request::TimeoutError" do
        logger.should receive(:<<).with(an_instance_of(MetaInspector::Request::TimeoutError))
        subject
      end
    end

    context "when request succeeds on third try" do
      before do
        Timeout.stub(:timeout).and_raise(Timeout::Error)
        Timeout.stub(:timeout).and_raise(Timeout::Error)
        Timeout.stub(:timeout).and_call_original
      end
      it "doesn't raise an exception" do
        logger.should_not receive(:<<)
        subject
      end
      it "succeeds as normal" do
        subject.content_type.should == "text/html"
      end
    end

    context "when request succeeds on fourth try" do
      before do
        Timeout.stub(:timeout).exactly(3).times.and_raise(Timeout::Error)
        # if it were called a fourth time, rspec would raise an error
        # so this implicitely tests the correct behavior
      end
      it "swallows all the timeout errors and raises MetaInspector::Request::TimeoutError" do
        logger.should receive(:<<).with(an_instance_of(MetaInspector::Request::TimeoutError))
        subject
      end
    end

  end

  private

  def url(initial_url)
    MetaInspector::URL.new(initial_url)
  end
end
