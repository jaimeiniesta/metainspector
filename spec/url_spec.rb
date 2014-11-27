require 'spec_helper'

describe MetaInspector::URL do
  it "should normalize URLs" do
    MetaInspector::URL.new('http://example.com').url.should == 'http://example.com/'
  end

  it 'should accept an URL with a scheme' do
    MetaInspector::URL.new('http://example.com/').url.should == 'http://example.com/'
  end

  it "should use http:// as a default scheme" do
    MetaInspector::URL.new('example.com').url.should == 'http://example.com/'
  end

  it "should accept an URL with international characters" do
    MetaInspector::URL.new('http://international.com/olé').url.should == 'http://international.com/ol%C3%A9'
  end

  it "should return the scheme" do
    MetaInspector::URL.new('http://example.com').scheme.should   == 'http'
    MetaInspector::URL.new('https://example.com').scheme.should  == 'https'
    MetaInspector::URL.new('example.com').scheme.should          == 'http'
  end

  it "should return the host" do
    MetaInspector::URL.new('http://example.com').host.should   == 'example.com'
    MetaInspector::URL.new('https://example.com').host.should  == 'example.com'
    MetaInspector::URL.new('example.com').host.should          == 'example.com'
  end

  it "should return the root url" do
    MetaInspector::URL.new('http://example.com').root_url.should        == 'http://example.com/'
    MetaInspector::URL.new('https://example.com').root_url.should       == 'https://example.com/'
    MetaInspector::URL.new('example.com').root_url.should               == 'http://example.com/'
    MetaInspector::URL.new('http://example.com/faqs').root_url.should   == 'http://example.com/'
  end

  describe "url=" do
    it "should update the url" do
      url = MetaInspector::URL.new('http://first.com/')

      url.url         = 'http://second.com/'
      url.url.should == 'http://second.com/'
    end

    it "should add the missing scheme and normalize" do
      url = MetaInspector::URL.new('http://first.com/')

      url.url         = 'second.com'
      url.url.should == 'http://second.com/'
    end
  end
end
