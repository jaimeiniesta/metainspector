require 'spec_helper'

describe 'Timeouts and retries' do
  let(:page_url) { 'http://timeouts.example.com/' }
  let(:html) { { status: 200, headers: { 'Content-Type' => 'text/html' }, body: '<title>Hi</title>' } }

  describe 'connection timeouts' do
    it 'raises MetaInspector::TimeoutError, keeping the original error as the cause' do
      stub_request(:get, page_url).to_raise(Net::OpenTimeout.new('Failed to open TCP connection'))

      expect do
        MetaInspector.new(page_url, retries: 0)
      end.to raise_error(MetaInspector::TimeoutError, /Failed to open TCP connection/) { |error|
        expect(error.cause).to be_a(Faraday::TimeoutError)
        expect(error.cause.wrapped_exception).to be_a(Net::OpenTimeout)
      }
    end

    it 'retries them' do
      request = stub_request(:get, page_url).to_raise(Net::OpenTimeout).then.to_return(html)

      page = MetaInspector.new(page_url, retries: 1)

      expect(page.title).to eq('Hi')
      expect(request).to have_been_requested.twice
    end

    it 'raises MetaInspector::TimeoutError after exhausting the retries' do
      request = stub_request(:get, page_url).to_raise(Net::OpenTimeout)

      expect do
        MetaInspector.new(page_url, retries: 2)
      end.to raise_error(MetaInspector::TimeoutError)

      expect(request).to have_been_requested.times(3)
    end

    it 'applies to HEAD requests too' do
      head_request = stub_request(:head, page_url).to_raise(Net::OpenTimeout)
      get_request = stub_request(:get, page_url).to_return(html)

      expect do
        MetaInspector.new(page_url, head_first: true, retries: 1)
      end.to raise_error(MetaInspector::TimeoutError)

      expect(head_request).to have_been_requested.twice
      expect(get_request).not_to have_been_requested
    end
  end

  describe 'other connection failures' do
    it 'still raise MetaInspector::RequestError without retrying' do
      request = stub_request(:get, page_url).to_raise(Errno::ECONNREFUSED)

      expect do
        MetaInspector.new(page_url, retries: 2)
      end.to raise_error(MetaInspector::RequestError)

      expect(request).to have_been_requested.once
    end
  end

  describe 'deadline for each attempt' do
    # The deadline is connection_timeout + read_timeout + 1 seconds.
    let(:options) { { connection_timeout: 0.05, read_timeout: 0.05 } }

    it 'gives every retry its own deadline' do
      calls = 0
      request = stub_request(:get, page_url).to_return do
        calls += 1
        # Ends with a read timeout after more than half the deadline.
        sleep 0.7
        raise Net::ReadTimeout if calls == 1
        html
      end

      page = MetaInspector.new(page_url, **options, retries: 1)

      expect(page.title).to eq('Hi')
      expect(request).to have_been_requested.twice
    end

    # A server that keeps an attempt busy until the deadline, such as one that
    # streams forever, would hold the fetch for every retry (#188).
    it 'raises MetaInspector::TimeoutError without retrying when an attempt runs out of time' do
      request = stub_request(:get, page_url).to_return { sleep 1.5; html }

      expect do
        MetaInspector.new(page_url, **options, retries: 2)
      end.to raise_error(MetaInspector::TimeoutError, /execution expired/)

      expect(request).to have_been_requested.once
    end

    it 'applies to HEAD requests too' do
      head_request = stub_request(:head, page_url).to_return { sleep 1.5; html }
      get_request = stub_request(:get, page_url).to_return(html)

      expect do
        MetaInspector.new(page_url, **options, head_first: true, retries: 2)
      end.to raise_error(MetaInspector::TimeoutError)

      expect(head_request).to have_been_requested.once
      expect(get_request).not_to have_been_requested
    end
  end
end
