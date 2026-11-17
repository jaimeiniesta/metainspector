require 'spec_helper'

describe MetaInspector do
  it "returns a Document" do
    expect(MetaInspector.new('http://example.com').class).to eq(MetaInspector::Document)
  end

  describe "response caching" do
    # A memory cache (a Hash that responds to #read and #write)
    let(:cache) do
      store = Hash.new
      def store.read(k) self[k]; end
      def store.write(k, v) self[k] = v; end
      store
    end

    it "caches responses with faraday_options[:faraday_http_cache]" do
      MetaInspector.new('http://example.com', faraday_options: { faraday_http_cache: { store: cache } })

      expect(cache.keys).not_to be_empty
    end

    it "does not warn when the cache is configured inside faraday_options" do
      expect do
        MetaInspector.new('http://example.com', faraday_options: { faraday_http_cache: { store: cache } })
      end.not_to output.to_stderr
    end

    it "leaves the faraday_options hash it was given unchanged" do
      cache_options   = { store: cache }
      faraday_options = { faraday_http_cache: cache_options }

      MetaInspector.new('http://example.com', faraday_options: faraday_options)

      expect(faraday_options).to eq({ faraday_http_cache: { store: cache } })
      expect(cache_options).to eq({ store: cache })
    end

    it "raises ArgumentError for the top-level faraday_http_cache option removed in 6.0" do
      expect do
        MetaInspector.new('http://example.com', faraday_http_cache: { store: cache })
      end.to raise_error(ArgumentError, /faraday_http_cache.*faraday_options/)

      expect(cache).to be_empty
    end
  end
end
