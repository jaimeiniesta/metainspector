require 'spec_helper'

describe MetaInspector::Parser do
  let(:doc)    { MetaInspector::Document.new('http://pagerankalert.com') }
  let(:parser) { MetaInspector::Parser.new(doc) }

  it "should have a Nokogiri::HTML::Document as parsed" do
    parser.parsed.class.should == Nokogiri::HTML::Document
  end

  it "should return the document as a string" do
    parser.to_s.class.should == String
  end
end
