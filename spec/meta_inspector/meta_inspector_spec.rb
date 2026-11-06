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

    # The deprecation warning prints once per process, so each example starts as a fresh process would
    before { MetaInspector::Request.instance_variable_set(:@faraday_http_cache_deprecation_warned, nil) }

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

    it "still caches responses with the deprecated top-level faraday_http_cache option" do
      expect do
        MetaInspector.new('http://example.com', faraday_http_cache: { store: cache })
      end.to output.to_stderr

      expect(cache.keys).not_to be_empty
    end

    it "warns that the top-level faraday_http_cache option is deprecated" do
      expect do
        MetaInspector.new('http://example.com', faraday_http_cache: { store: cache })
      end.to output(/DEPRECATION.*faraday_http_cache.*faraday_options/).to_stderr
    end

    it "prints the deprecation warning only once per process" do
      expect do
        3.times { MetaInspector.new('http://example.com', faraday_http_cache: { store: cache }) }
      end.to output(/\ADEPRECATION WARNING: [^\n]*\n\z/).to_stderr
    end

    it "raises ArgumentError when the cache is configured in both places" do
      expect do
        MetaInspector.new('http://example.com', faraday_http_cache: { store: cache },
                                                faraday_options:    { faraday_http_cache: { store: cache } })
      end.to raise_error(ArgumentError, /faraday_http_cache/)
    end
  end
end
