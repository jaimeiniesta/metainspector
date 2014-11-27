require 'spec_helper'

describe MetaInspector do
  it "returns a Document" do
    MetaInspector.new('http://example.com').class.should == MetaInspector::Document
  end
end
