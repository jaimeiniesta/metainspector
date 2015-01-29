require 'spec_helper'

describe MetaInspector do
  it "returns a Document" do
    expect(MetaInspector.new('http://example.com').class).to eq(MetaInspector::Document)
  end
end
