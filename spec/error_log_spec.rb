# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector::ErrorLog do
  describe "storing errors" do
    let(:logger) { MetaInspector::ErrorLog.new }

    it "should store errors" do
      expect {
        logger << "an error message"
      }.to change { logger.errors.length }.from(0).to(1)
    end

    it "should return stored errors" do
      logger << "first message"
      logger << "second message"

      logger.errors.should == ["first message", "second message"]
    end
  end

  describe "warning about errors" do
    it "should be quiet by default" do
      MetaInspector::ErrorLog.new.verbose.should == false
    end

    it "should warn about the error if verbose mode on" do
      verbose_logger = MetaInspector::ErrorLog.new(verbose: true)
      verbose_logger.should_receive(:warn)
      verbose_logger << "an error message"
    end

    it "should not warn about the error if verbose mode off" do
      quiet_logger = MetaInspector::ErrorLog.new(verbose: false)
      quiet_logger.should_not_receive(:warn)
      quiet_logger << "an error message"
    end
  end

end
