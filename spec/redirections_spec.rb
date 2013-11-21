# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector do
  describe "redirections" do
    describe "safe redirections (HTTP to HTTPS)" do
      it "disallows safe redirections by default" do
        m = MetaInspector.new("http://facebook.com")
        m.to_hash
        m.should_not be_ok
        m.exceptions.first.message.should == "redirection forbidden: http://facebook.com/ -> https://www.facebook.com/"
      end

      it "allows safe redirections when :allow_redirections => :safe" do
        m = MetaInspector.new("http://facebook.com", :allow_redirections => :safe)
        m.to_hash
        m.should be_ok
      end

      it "allows safe redirections when :allow_redirections => :all" do
        m = MetaInspector.new("http://facebook.com", :allow_redirections => :all)
        m.to_hash
        m.should be_ok
      end
    end

    describe "unsafe redirections (HTTPS to HTTP)" do
      it "disallows unsafe redirections by default" do
        m = MetaInspector.new("https://unsafe-facebook.com")
        m.to_hash
        m.should_not be_ok
        m.exceptions.first.message.should == "redirection forbidden: https://unsafe-facebook.com/ -> http://unsafe-facebook.com/"
      end

      it "disallows unsafe redirections when :allow_redirections => :safe" do
        m = MetaInspector.new("https://unsafe-facebook.com", :allow_redirections => :safe)
        m.to_hash
        m.should_not be_ok
        m.exceptions.first.message.should == "redirection forbidden: https://unsafe-facebook.com/ -> http://unsafe-facebook.com/"
      end

      it "allows unsafe redirections when :allow_redirections => :all" do
        m = MetaInspector.new("https://unsafe-facebook.com", :allow_redirections => :all)
        m.to_hash
        m.should be_ok
      end
    end

    describe "Redirections should update the base_uri" do
      it "updates the base_uri on safe redirections" do
        m = MetaInspector.new("http://facebook.com", :allow_redirections => :safe) 
        m.to_hash
        m.url.should == "https://www.facebook.com/"
      end

      it "updates the base_uri on all redirections" do
        m = MetaInspector.new("http://facebook.com", :allow_redirections => :all)
        m.to_hash

        m.url.should == "https://www.facebook.com/"
      end
    end
  end
end
