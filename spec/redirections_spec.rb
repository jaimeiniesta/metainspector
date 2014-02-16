# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector do
  describe "redirections" do
    let(:logger) { MetaInspector::ExceptionLog.new }

    describe "safe redirections (HTTP to HTTPS)" do
      it "disallows safe redirections by default" do
        logger.should receive(:<<).with(an_instance_of(RuntimeError))

        MetaInspector.new("http://facebook.com", exception_log: logger)
      end

      it "allows safe redirections when :allow_redirections => :safe" do
        logger.should_not receive(:<<)

        m = MetaInspector.new("http://facebook.com", :allow_redirections => :safe, exception_log: logger)

        m.url.should == "https://www.facebook.com/"
      end

      it "allows safe redirections when :allow_redirections => :all" do
        logger.should_not receive(:<<)

        m = MetaInspector.new("http://facebook.com", :allow_redirections => :all, exception_log: logger)

        m.url.should == "https://www.facebook.com/"
      end
    end

    describe "unsafe redirections (HTTPS to HTTP)" do
      it "disallows unsafe redirections by default" do
        logger.should receive(:<<).with(an_instance_of(RuntimeError))

        MetaInspector.new("https://unsafe-facebook.com", exception_log: logger)
      end

      it "disallows unsafe redirections when :allow_redirections => :safe" do
        logger.should receive(:<<).with(an_instance_of(RuntimeError))

        MetaInspector.new("https://unsafe-facebook.com", :allow_redirections => :safe, exception_log: logger)
      end

      it "allows unsafe redirections when :allow_redirections => :all" do
        logger.should_not receive(:<<)

        m = MetaInspector.new("https://unsafe-facebook.com", :allow_redirections => :all, exception_log: logger)

        m.url.should == "http://unsafe-facebook.com/"
      end
    end

    describe "Redirections should update the base_uri" do
      it "updates the base_uri on safe redirections" do
        m = MetaInspector.new("http://facebook.com", :allow_redirections => :safe)

        m.url.should == "https://www.facebook.com/"
      end

      it "updates the base_uri on all redirections" do
        m = MetaInspector.new("http://facebook.com", :allow_redirections => :all)

        m.url.should == "https://www.facebook.com/"
      end
    end
  end
end
