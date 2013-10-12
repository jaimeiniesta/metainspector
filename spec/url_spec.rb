# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector::URL do
  it "should normalize URLs" do
    MetaInspector::URL.new('http://example.com').url.should == 'http://example.com/'
  end

  it 'should accept an URL with a scheme' do
    MetaInspector::URL.new('http://example.com/').url.should == 'http://example.com/'
  end

  it "should use http:// as a default scheme" do
    MetaInspector::URL.new('example.com').url.should == 'http://example.com'
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
  
  describe "exception handling" do
    it "should handle URI::InvalidURIError" do
      expect {
        @malformed = MetaInspector::URL.new('javascript://')
      }.to_not raise_error

      @malformed.exceptions.first.class.should == URI::InvalidURIError
    end
    
    it "should handle URI::InvalidComponentError" do
      expect {
        @malformed = MetaInspector::URL.new('mailto:email(at)example.com')
      }.to_not raise_error

      @malformed.exceptions.first.class.should == URI::InvalidComponentError
    end
  end
end
