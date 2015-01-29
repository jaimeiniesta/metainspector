require 'spec_helper'

describe MetaInspector::URL do
  it "should normalize URLs" do
    expect(MetaInspector::URL.new('http://example.com').url).to eq('http://example.com/')
  end

  it 'should accept an URL with a scheme' do
    expect(MetaInspector::URL.new('http://example.com/').url).to eq('http://example.com/')
  end

  it "should use http:// as a default scheme" do
    expect(MetaInspector::URL.new('example.com').url).to eq('http://example.com/')
  end

  it "should accept an URL with international characters" do
    expect(MetaInspector::URL.new('http://international.com/olé').url).to eq('http://international.com/ol%C3%A9')
  end

  it "should return the scheme" do
    expect(MetaInspector::URL.new('http://example.com').scheme).to   eq('http')
    expect(MetaInspector::URL.new('https://example.com').scheme).to  eq('https')
    expect(MetaInspector::URL.new('example.com').scheme).to          eq('http')
  end

  it "should return the host" do
    expect(MetaInspector::URL.new('http://example.com').host).to   eq('example.com')
    expect(MetaInspector::URL.new('https://example.com').host).to  eq('example.com')
    expect(MetaInspector::URL.new('example.com').host).to          eq('example.com')
  end

  it "should return the root url" do
    expect(MetaInspector::URL.new('http://example.com').root_url).to        eq('http://example.com/')
    expect(MetaInspector::URL.new('https://example.com').root_url).to       eq('https://example.com/')
    expect(MetaInspector::URL.new('example.com').root_url).to               eq('http://example.com/')
    expect(MetaInspector::URL.new('http://example.com/faqs').root_url).to   eq('http://example.com/')
  end

  describe "url=" do
    it "should update the url" do
      url = MetaInspector::URL.new('http://first.com/')

      url.url         = 'http://second.com/'
      expect(url.url).to eq('http://second.com/')
    end

    it "should add the missing scheme and normalize" do
      url = MetaInspector::URL.new('http://first.com/')

      url.url         = 'second.com'
      expect(url.url).to eq('http://second.com/')
    end
  end
end
