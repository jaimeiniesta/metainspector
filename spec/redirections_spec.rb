# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector do
  describe "redirections" do
    describe "safe redirections (HTTP to HTTPS)" do
      it "allows safe redirections by default" do
        m = MetaInspector.new("http://facebook.com")
        m.title.should == "Hello From Facebook"
        m.should be_ok
      end

      it "allows safe redirections when specifically set to true" do
        m = MetaInspector.new("http://facebook.com", :allow_safe_redirections => true)
        m.title.should == "Hello From Facebook"
        m.should be_ok
      end

      it "disallows safe redirections if set to false" do
        m = MetaInspector.new("http://facebook.com", :allow_safe_redirections => false)
        m.title.should be_nil
        m.should_not be_ok
        m.errors.first.should == "Scraping exception: redirection forbidden: http://facebook.com -> https://www.facebook.com/"
      end
    end

    describe "unsafe redirections (HTTPS to HTTP)" do
      it "disallows unsafe redirections by default" do
        m = MetaInspector.new("https://unsafe-facebook.com")
        m.title.should be_nil
        m.should_not be_ok
        m.errors.first.should == "Scraping exception: redirection forbidden: https://unsafe-facebook.com -> http://unsafe-facebook.com/"
      end

      it "disallows unsafe redirections when specifically set to false" do
        m = MetaInspector.new("https://unsafe-facebook.com", :allow_unsafe_redirections => false)
        m.title.should be_nil
        m.should_not be_ok
        m.errors.first.should == "Scraping exception: redirection forbidden: https://unsafe-facebook.com -> http://unsafe-facebook.com/"
      end

      it "allows unsafe redirections if set to true" do
        m = MetaInspector.new("https://unsafe-facebook.com", :allow_unsafe_redirections => true)
        m.title.should == "Hello From Unsafe Facebook"
        m.should be_ok
      end
    end
  end
end
