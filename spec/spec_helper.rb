# -*- encoding: utf-8 -*-

$: << File.join(File.dirname(__FILE__), "/../lib")
require 'meta_inspector'
require 'fakeweb'
require "pry"

FakeWeb.allow_net_connect = false

def fixture_file(filename)
  return '' if filename == ''
  file_path = File.expand_path(File.dirname(__FILE__) + '/fixtures/' + filename)
  File.read(file_path)
end

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.treat_symbols_as_metadata_keys_with_true_values = true #rspec 3 default
end

#######################
# Faked web responses #
#######################

FakeWeb.register_uri(:get, "http://example.com/", :response => fixture_file("empty_page.response"))
FakeWeb.register_uri(:get, "http://pagerankalert.com", :response => fixture_file("pagerankalert.com.response"))
FakeWeb.register_uri(:get, "pagerankalert.com", :response => fixture_file("pagerankalert.com.response"))
FakeWeb.register_uri(:get, "http://www.alazan.com", :response => fixture_file("alazan.com.response"))
FakeWeb.register_uri(:get, "http://alazan.com/websolution.asp", :response => fixture_file("alazan_websolution.response"))
FakeWeb.register_uri(:get, "http://www.theonion.com/articles/apple-claims-new-iphone-only-visible-to-most-loyal,2772/", :response => fixture_file("theonion.com.response"))
FakeWeb.register_uri(:get, "http://theonion-no-description.com", :response => fixture_file("theonion-no-description.com.response"))
FakeWeb.register_uri(:get, "http://www.iteh.at", :response => fixture_file("iteh.at.response"))
FakeWeb.register_uri(:get, "http://www.tea-tron.com/jbravo/blog/", :response => fixture_file("tea-tron.com.response"))
FakeWeb.register_uri(:get, "http://www.guardian.co.uk/media/pda/2011/sep/15/techcrunch-arrington-startups", :response => fixture_file("guardian.co.uk.response"))
FakeWeb.register_uri(:get, "http://protocol-relative.com", :response => fixture_file("protocol_relative.response"))
FakeWeb.register_uri(:get, "https://protocol-relative.com", :response => fixture_file("protocol_relative.response"))
FakeWeb.register_uri(:get, "http://example.com/nonhttp", :response => fixture_file("nonhttp.response"))
FakeWeb.register_uri(:get, "http://example.com/invalid_href", :response => fixture_file("invalid_href.response"))
FakeWeb.register_uri(:get, "http://example.com/malformed_href", :response => fixture_file("malformed_href.response"))
FakeWeb.register_uri(:get, "http://www.youtube.com/watch?v=iaGSSrp49uc", :response => fixture_file("youtube.response"))
FakeWeb.register_uri(:get, "http://markupvalidator.com/faqs", :response => fixture_file("markupvalidator_faqs.response"))
FakeWeb.register_uri(:get, "https://twitter.com/markupvalidator", :response => fixture_file("twitter_markupvalidator.response"))
FakeWeb.register_uri(:get, "http://example.com/empty", :response => fixture_file("empty_page.response"))
FakeWeb.register_uri(:get, "http://international.com", :response => fixture_file("international.response"))
FakeWeb.register_uri(:get, "http://charset000.com", :response => fixture_file("charset_000.response"))
FakeWeb.register_uri(:get, "http://charset001.com", :response => fixture_file("charset_001.response"))
FakeWeb.register_uri(:get, "http://charset002.com", :response => fixture_file("charset_002.response"))
FakeWeb.register_uri(:get, "http://www.inkthemes.com/", :response => fixture_file("wordpress_site.response"))
FakeWeb.register_uri(:get, "http://pagerankalert.com/image.png", :body => "Image", :content_type => "image/png")
FakeWeb.register_uri(:get, "http://pagerankalert.com/file.tar.gz", :body => "Image", :content_type => "application/x-gzip")
FakeWeb.register_uri(:get, "http://example.com/meta-tags", :response => fixture_file("meta_tags.response"))

# These examples are used to test relative links
FakeWeb.register_uri(:get, "http://relative.com/", :response => fixture_file("relative_links.response"))
FakeWeb.register_uri(:get, "http://relative.com/company", :response => fixture_file("relative_links.response"))
FakeWeb.register_uri(:get, "http://relative.com/company/", :response => fixture_file("relative_links.response"))

FakeWeb.register_uri(:get, "http://relativewithbase.com/",                :response => fixture_file("relative_links_with_base.response"))
FakeWeb.register_uri(:get, "http://relativewithbase.com/company/page2",   :response => fixture_file("relative_links_with_base.response"))
FakeWeb.register_uri(:get, "http://relativewithbase.com/company/page2/",  :response => fixture_file("relative_links_with_base.response"))

# These examples are used to test the redirections from HTTP to HTTPS and vice versa
# http://facebook.com => https://facebook.com
FakeWeb.register_uri(:get, "http://facebook.com/",          :response => fixture_file("facebook.com.response"))
FakeWeb.register_uri(:get, "https://www.facebook.com/",     :response => fixture_file("https.facebook.com.response"))

# https://unsafe-facebook.com => http://unsafe-facebook.com
FakeWeb.register_uri(:get, "https://unsafe-facebook.com/",  :response => fixture_file("unsafe_https.facebook.com.response"))
FakeWeb.register_uri(:get, "http://unsafe-facebook.com/",   :response => fixture_file("unsafe_facebook.com.response"))
