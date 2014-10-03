# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector do
  describe "redirections" do
    let(:logger) { MetaInspector::ExceptionLog.new }

    context "when redirecitons are turned off" do
      it "disallows redirections" do
        logger.should receive(:<<).with(an_instance_of(RuntimeError))

        MetaInspector.new("http://facebook.com", :allow_redirections => false, exception_log: logger)
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

    context "when allow_redirections is not given a boolean" do
      it "raises an error" do
        expect{
          MetaInspector.new("http://facebook.com", :allow_redirections => :hello, exception_log: logger)
        }.to raise_error(ArgumentError)
      end
    end

  end
end
