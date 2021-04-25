require 'spec_helper'

describe MetaInspector do
  describe "redirections" do
    context "when redirections are turned off" do
      it "disallows redirections" do
        page = MetaInspector.call("http://facebook.com", :allow_redirections => false)

        expect(page.url).to eq("http://facebook.com/")
      end
    end

    context "when redirections are on (default)" do
      it "allows follows redirections" do
        page = MetaInspector.call("http://facebook.com")

        expect(page.url).to eq("https://www.facebook.com/")
      end
    end

    context "when there are too many redirects" do
      before do
        12.times { |i| register_redirect(i, i+1) }
      end

      it "raises an error" do
        expect {
          MetaInspector.call("http://example.org/1")
        }.to raise_error MetaInspector::RequestError
      end
    end

    context "when there are cookies required for proper redirection" do
      it "allows follows redirections while sending the cookies" do
        stub_request(:get, "http://blogs.clarionledger.com/dechols/2014/03/24/digital-medicine/")
          .to_return(:status => 302,
                     :headers => {
                                   "Location" => "http://blogs.clarionledger.com/dechols/2014/03/24/digital-medicine/?nclick_check=1",
                                   "Set-Cookie" => "EMETA_COOKIE_CHECK=1; path=/; domain=clarionledger.com"
                                 })

        stub_request(:get, "http://blogs.clarionledger.com/dechols/2014/03/24/digital-medicine/?nclick_check=1")
          .with(:headers => {"Cookie" => "EMETA_COOKIE_CHECK=1"})

        page = MetaInspector.call("http://blogs.clarionledger.com/dechols/2014/03/24/digital-medicine/")

        expect(page.url).to eq("http://blogs.clarionledger.com/dechols/2014/03/24/digital-medicine/?nclick_check=1")
      end
    end
  end

  private

  def register_redirect(from, to)
    stub_request(:get, "http://example.org/#{from}")
      .to_return(:status => 302, :body => "", :headers => { "Location" => "http://example.org/#{to}" })
  end
end
