# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector::Request do

  describe "read" do
    it "should return the content of the page" do
      page_request = MetaInspector::Request.new(url('http://pagerankalert.com'))

      page_request.read[0..14].should == "<!DOCTYPE html>"
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

    it "should handle timeouts" do
      logger.should receive(:<<).with(an_instance_of(Timeout::Error))

      impatient = MetaInspector::Request.new(url('http://example.com'), timeout: 0.0000000000001, exception_log: logger)
      impatient.read
    end

    it "should handle socket errors" do
      logger.should receive(:<<).with(an_instance_of(SocketError))

      nowhere = MetaInspector::Request.new(url('http://caca232dsdsaer3sdsd-asd343.org'), exception_log: logger)
      nowhere.read
    end
  end

  private

  def url(initial_url)
    MetaInspector::URL.new(initial_url)
  end
end
