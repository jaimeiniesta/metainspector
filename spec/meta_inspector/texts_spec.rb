require 'spec_helper'

describe MetaInspector do
  it "should get the title from the head section" do
    p = MetaInspector.new('http://example.com')
    p.title.should == 'An example page'
  end

  describe '#description' do
    it "should find description from meta description" do
      page = MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc')

      page.description.should == "This is Youtube"
    end

    it "should find a secondary description if no meta description" do
      @m = MetaInspector.new('http://theonion-no-description.com')
      @m.description.should == "SAN FRANCISCO—In a move expected to revolutionize the mobile device industry, Apple launched its fastest and most powerful iPhone to date Tuesday, an innovative new model that can only be seen by the company's hippest and most dedicated customers. This is secondary text picked up because of a missing meta description."
    end
  end
end
