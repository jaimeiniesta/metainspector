# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector::Request do

  describe "read" do
    it "should return the content of the page" do
      page_request = MetaInspector::Request.new('http://pagerankalert.com')

      page_request.read[0..14].should == "<!DOCTYPE html>"
    end
  end

  describe "content_type" do
    it "should return the correct content type of the url for html pages" do
      page_request = MetaInspector.new('http://pagerankalert.com')

      page_request.content_type.should == "text/html"
    end

    it "should return the correct content type of the url for non html pages" do
      image_request = MetaInspector.new('http://pagerankalert.com/image.png')

      image_request.content_type.should == "image/png"
    end
  end

  describe 'exception handling' do
    before(:each) do
      FakeWeb.allow_net_connect = true
    end

    after(:each) do
      FakeWeb.allow_net_connect = false
    end

    it "should handle timeouts" do
      impatient = MetaInspector::Request.new('http://example.com', timeout: 0.0000000000001)

      expect {
        impatient.read.should be_nil
      }.to change { impatient.errors.size }

      impatient.errors.first.should == "execution expired"
    end

    it "should handle socket errors" do
      nowhere = MetaInspector::Request.new('http://caca232dsdsaer3sdsd-asd343.org')

      expect {
        nowhere.read.should be_nil
      }.to change { nowhere.errors.size }

      nowhere.errors.first.should == "getaddrinfo: nodename nor servname provided, or not known"
    end
  end
end
