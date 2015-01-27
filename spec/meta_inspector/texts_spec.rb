require 'spec_helper'

describe MetaInspector do
  it "should get the title from the head section" do
    page = MetaInspector.new('http://example.com')
    page.title.should == 'An example page'
  end

  describe '#best_title' do
    it "should find 'head title' when that's the only thing" do
      page = MetaInspector.new('http://example.com/title_in_head')
      page.best_title.should == 'This title came from the head'
    end

    it "should find 'body title' when that's the only thing" do
      page = MetaInspector.new('http://example.com/title_in_body')
      page.best_title.should == 'This title came from the body, not the head'
    end

    it "should find 'og:title' when that's the only thing" do
      page = MetaInspector.new('http://example.com/meta-tags')
      page.best_title.should == 'An OG title'
    end

    it "should find the first <h1> when that's the only thing" do
      page = MetaInspector.new('http://example.com/title_in_h1')
      page.best_title.should == 'This title came from the first h1'
    end

    it "should choose the longest candidate from the available options" do
      page = MetaInspector.new('http://example.com/title_best_choice')
      page.best_title.should == 'This title came from the first h1 and should be the longest of them all, so should be chosen'
    end

    it "should strip leading and trailing whitespace and all line breaks" do

    end

  end

  describe '#description' do
    it "should find description from meta description" do
      page = MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc')

      page.description.should == "This is Youtube"
    end

    it "should find a secondary description if no meta description" do
      page = MetaInspector.new('http://theonion-no-description.com')
      page.description.should == "SAN FRANCISCO—In a move expected to revolutionize the mobile device industry, Apple launched its fastest and most powerful iPhone to date Tuesday, an innovative new model that can only be seen by the company's hippest and most dedicated customers. This is secondary text picked up because of a missing meta description."
    end
  end
end
