# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), "/spec_helper")

describe MetaInspector do
  describe "redirections" do
    let(:logger) { MetaInspector::ExceptionLog.new }

    context "when redirections are turned off" do
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
    end

    context "when there are cookies required for proper redirection" do
      before(:all){WebMock.enable!}
      after(:all){WebMock.disable!}

      it "allows follows redirections while sending the cookies" do
        stub_request(:get, "http://blogs.clarionledger.com/dechols/2014/03/24/digital-medicine/").to_return(
          :status => 302,
          :headers => { 
            "Location" => "http://blogs.clarionledger.com/dechols/2014/03/24/digital-medicine/?nclick_check=1",
            "Set-Cookie" => "EMETA_COOKIE_CHECK=1; path=/; domain=clarionledger.com"
          })
        stub_request(:get, "http://blogs.clarionledger.com/dechols/2014/03/24/digital-medicine/?nclick_check=1")
          .with(:headers => {"Cookie" => "EMETA_COOKIE_CHECK=1"})
        logger.should_not receive(:<<)

        m = MetaInspector.new("http://blogs.clarionledger.com/dechols/2014/03/24/digital-medicine/", exception_log: logger)

        m.url.should == "http://blogs.clarionledger.com/dechols/2014/03/24/digital-medicine/?nclick_check=1"
      end      
    end
  end
end
