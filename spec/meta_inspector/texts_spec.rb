require 'spec_helper'

describe MetaInspector do
  it "should get the title from the head section" do
    page = MetaInspector.new('http://example.com')
    expect(page.title).to eq('An example page')
  end

  describe '#best_title' do
    it "should find 'head title' when that's the only thing" do
      page = MetaInspector.new('http://example.com/title_in_head')
      expect(page.best_title).to eq('This title came from the head')
    end

    it "should find 'body title' when that's the only thing" do
      page = MetaInspector.new('http://example.com/title_in_body')
      expect(page.best_title).to eq('This title came from the body, not the head')
    end

    it "should find 'og:title' when that's the only thing" do
      page = MetaInspector.new('http://example.com/meta-tags')
      expect(page.best_title).to eq('An OG title')
    end

    it "should find the first <h1> when that's the only thing" do
      page = MetaInspector.new('http://example.com/title_in_h1')
      expect(page.best_title).to eq('This title came from the first h1')
    end

    it "should choose the longest candidate from the available options" do
      page = MetaInspector.new('http://example.com/title_best_choice')
      expect(page.best_title).to eq('This title came from the first h1 and should be the longest of them all, so should be chosen')
    end

    it "should strip leading and trailing whitespace and all line breaks" do
      page = MetaInspector.new('http://example.com/title_in_head_with_whitespace')
      expect(page.best_title).to eq('This title came from the head and has leading and trailing whitespace')
    end

    it "should return nil if none of the candidates are present" do
      page = MetaInspector.new('http://example.com/title_not_present')
      expect(page.best_title).to be(nil)
    end

  end

  describe '#description' do
    it "should find description from meta description" do
      page = MetaInspector.new('http://www.youtube.com/watch?v=iaGSSrp49uc')

      expect(page.description).to eq("This is Youtube")
    end

    it "should find a secondary description if no meta description" do
      page = MetaInspector.new('http://theonion-no-description.com')
      expect(page.description).to eq("SAN FRANCISCO—In a move expected to revolutionize the mobile device industry, Apple launched its fastest and most powerful iPhone to date Tuesday, an innovative new model that can only be seen by the company's hippest and most dedicated customers. This is secondary text picked up because of a missing meta description.")
    end
  end
end
