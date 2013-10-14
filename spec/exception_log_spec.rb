# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector::ExceptionLog do
  let(:logger) { MetaInspector::ExceptionLog.new }

  describe "storing exceptions" do
    it "should store exceptions" do
      expect {
        logger << StandardError.new("an error message")
      }.to change { logger.exceptions.length }.from(0).to(1)
    end

    it "should return stored exceptions" do
      first   = StandardError.new("first message")
      second  = StandardError.new("second message")

      logger << first
      logger << second

      logger.exceptions.should == [first, second]
    end
  end

  describe "ok?" do
    it "should be true if no exceptions stored" do
      logger.should be_ok
    end

    it "should be false if some exception stored" do
      logger << StandardError.new("some message")
      logger.should_not be_ok
    end
  end

  describe "warn_level" do
    it "should be quiet by default" do
      MetaInspector::ExceptionLog.new.warn_level.should be_nil
    end

    it "should warn about the error if warn_level is :warn" do
      verbose_logger = MetaInspector::ExceptionLog.new(warn_level: :warn)
      exception      = StandardError.new("an error message")

      verbose_logger.should_receive(:warn).with(exception)
      verbose_logger << exception
    end

    it "should raise exceptions when warn_level is :raise" do
      raiser_logger = MetaInspector::ExceptionLog.new(warn_level: :raise)
      exception     = StandardError.new("this should be raised")

      expect {
        raiser_logger << exception
      }.to raise_exception(StandardError, "this should be raised")
    end
  end
end
