require 'spec_helper'

describe MetaInspector::Parser do
  let(:logger) { MetaInspector::ExceptionLog.new }

  describe 'Doing a basic scrape' do
    before(:each) do
      @m = MetaInspector::Parser.new(doc 'http://pagerankalert.com')
    end

    it "should have a Nokogiri::HTML::Document as parsed" do
      @m.parsed.class.should == Nokogiri::HTML::Document
    end

    it "should return the document as a string" do
      @m.to_s.class.should == String
    end
  end

  private

  def doc(url, options = { exception_log: logger })
    MetaInspector::Document.new(url, options)
  end
end
