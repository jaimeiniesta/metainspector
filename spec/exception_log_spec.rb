require 'spec_helper'

describe MetaInspector::ExceptionLog do

  describe "warn_level" do
    it "should be :raise by default" do
      expect(MetaInspector::ExceptionLog.new.warn_level).to eq(:raise)
    end

    it "should raise exceptions when warn_level is :raise" do
      logger    = MetaInspector::ExceptionLog.new(warn_level: :raise)
      exception = StandardError.new("this should be raised")

      expect {
        logger << exception
      }.to raise_exception(StandardError, "this should be raised")
    end

    it "should warn about the error if warn_level is :warn" do
      logger    = MetaInspector::ExceptionLog.new(warn_level: :warn)
      exception = StandardError.new("an error message")

      expect(logger).to receive(:warn).with(exception)
      logger << exception
    end

    it "should store the error if warn_level is :store" do
      logger    = MetaInspector::ExceptionLog.new(warn_level: :store)
      exception = StandardError.new("an error message")
      expect {
        logger << exception
      }.to change { logger.exceptions.size }.by(1)
    end
  end

  describe "storing exceptions" do
    let(:logger) { MetaInspector::ExceptionLog.new(warn_level: :store) }

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

      expect(logger.exceptions).to eq([first, second])
    end

    describe "ok?" do
      it "should be true if no exceptions stored" do
        expect(logger).to be_ok
      end

      it "should be false if some exception stored" do
        logger << StandardError.new("some message")
        expect(logger).not_to be_ok
      end

      it "should warn about misuse if warn_level is :raise" do
        logger    = MetaInspector::ExceptionLog.new(warn_level: :raise)
        expect(logger).to receive(:warn).with("ExceptionLog#ok? should only be used when warn_level is :store")
        logger.ok?
      end

      it "should warn about misuse if warn_level is :warn" do
        logger    = MetaInspector::ExceptionLog.new(warn_level: :warn)
        expect(logger).to receive(:warn).with("ExceptionLog#ok? should only be used when warn_level is :store")
        logger.ok?
      end
    end
  end

end
