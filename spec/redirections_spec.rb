# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector do
  describe "redirections" do
    let(:logger) { MetaInspector::ExceptionLog.new }

    context "when redirecitons are turned off" do
      it "disallows redirections" do
        m = MetaInspector.new("http://facebook.com", :allow_redirections => false, exception_log: logger)
        m.url.should == "http://facebook.com/"
      end
    end

    context "when redirections are on (default)" do
      it "allows follows redirections" do
        logger.should_not receive(:<<)

        m = MetaInspector.new("http://facebook.com", exception_log: logger)

        m.url.should == "https://www.facebook.com/"
      end

      it "updates the base_uri" do
        m = MetaInspector.new("http://facebook.com")

        m.url.should == "https://www.facebook.com/"
      end
    end

  end
end
