require 'spec_helper'

describe MetaInspector do
  it "returns a Document" do
    expect(MetaInspector.new('http://example.com').class).to eq(MetaInspector::Document)
  end

  it "cache request" do
    # Creates a memory cache (a Hash that responds to #read, #write and #delete)
    cache = Hash.new
    def cache.read(k) self[k]; end
    def cache.write(k, v) self[k] = v; end

    expect(MetaInspector.new('http://example.com', warn_level: :store, faraday_cache_options: { store: cache })).to be_ok

    expect(cache.keys).not_to be_empty
  end
end
