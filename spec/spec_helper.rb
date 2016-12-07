$: << File.join(File.dirname(__FILE__), "/../lib")
require 'meta_inspector'
require 'fakeweb'
require "webmock/rspec"
require "pry"

FakeWeb.allow_net_connect = false
WebMock.disable!

def fixture_file(filename)
  return '' if filename == ''
  file_path = File.expand_path(File.dirname(__FILE__) + '/fixtures/' + filename)
  File.read(file_path)
end

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end

#######################
# Faked web responses #
#######################

# We're reorganizing fixtures, trying to combine them on as few as possible response files
# For each change in the fixtures, a comment should be included explaining why it's needed
# This is the base page to be used in the examples
FakeWeb.register_uri(:get, "http://example.com/", :response => fixture_file("example.response"))

# Used to test response status codes
FakeWeb.register_uri(:get, "http://example.com/404", :response => fixture_file("404.response"))

# Used to test headers
FakeWeb.register_uri(:get, "http://example.com/no-content-type", :response => fixture_file("no-content-type.response"))

# Used to test largest image in page logic
FakeWeb.register_uri(:get, "http://example.com/largest_image_in_html", :response => fixture_file("largest_image_in_html.response"))
FakeWeb.register_uri(:get, "http://example.com/largest_image_using_image_size", :response => fixture_file("largest_image_using_image_size.response"))
FakeWeb.register_uri(:get, "http://example.com/malformed_image_in_html", :response => fixture_file("malformed_image_in_html.response"))
FakeWeb.register_uri(:get, "http://example.com/10x10", :response => fixture_file("10x10.jpg.response"))
FakeWeb.register_uri(:get, "http://example.com/100x100", :response => fixture_file("100x100.jpg.response"))
FakeWeb.register_uri(:get, "http://www.24-horas.mx/mexico-firma-acuerdo-bilateral-automotriz-con-argentina/", :response => fixture_file("relative_og_image.response"))

# Used to test canonical URLs in head
FakeWeb.register_uri(:get, "http://example.com/head_links", :response => fixture_file("head_links.response"))
FakeWeb.register_uri(:get, "https://example.com/head_links", :response => fixture_file("head_links.response"))
FakeWeb.register_uri(:get, "http://example.com/broken_head_links", :response => fixture_file("broken_head_links.response"))

# Used to test best_title logic
FakeWeb.register_uri(:get, "http://example.com/title_in_head", :response => fixture_file("title_in_head.response"))
FakeWeb.register_uri(:get, "http://example.com/title_in_body", :response => fixture_file("title_in_body.response"))
FakeWeb.register_uri(:get, "http://example.com/title_in_h1", :response => fixture_file("title_in_h1.response"))
FakeWeb.register_uri(:get, "http://example.com/title_best_choice", :response => fixture_file("title_best_choice.response"))
FakeWeb.register_uri(:get, "http://example.com/title_in_head_with_whitespace", :response => fixture_file("title_in_head_with_whitespace.response"))
FakeWeb.register_uri(:get, "http://example.com/title_not_present", :response => fixture_file("title_not_present.response"))
# best_title now has specific logic for youtube
FakeWeb.register_uri(:get, "http://www.youtube.com/watch?v=short_title", :response => fixture_file("youtube_short_title.response"))

# Used to test best_description logic
FakeWeb.register_uri(:get, "http://example.com/desc_in_meta", :response => fixture_file("desc_in_meta.response"))
FakeWeb.register_uri(:get, "http://example.com/desc_in_og", :response => fixture_file("desc_in_og.response"))
FakeWeb.register_uri(:get, "http://example.com/desc_in_twitter", :response => fixture_file("desc_in_twitter.response"))

# These are older fixtures
FakeWeb.register_uri(:get, "http://pagerankalert.com", :response => fixture_file("pagerankalert.com.response"))
FakeWeb.register_uri(:get, "http://pagerankalert-shortcut.com", :response => fixture_file("pagerankalert-shortcut.com.response"))
FakeWeb.register_uri(:get, "http://pagerankalert-shortcut-and-icon.com", :response => fixture_file("pagerankalert-shortcut-and-icon.com.response"))
FakeWeb.register_uri(:get, "http://pagerankalert-touch-icon.com", :response => fixture_file("pagerankalert-touch-icon.com.response"))
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
FakeWeb.register_uri(:get, "http://example.com/invalid_byte_seq", :response => fixture_file("invalid_byte_seq.response"))
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

# These examples are used to test normalize URLs
FakeWeb.register_uri(:get, "http://example.com/%EF%BD%9E", :response => fixture_file("example.response"))
FakeWeb.register_uri(:get, "http://example.com/~", :response => fixture_file("example.response"))

# Example to test correct encoding
FakeWeb.register_uri(:get, "http://example-rtl.com/", :response => fixture_file("encoding.response"))

# Example used to test empty description metatags
FakeWeb.register_uri(:get, "http://example.com/empty-meta-description", :response => fixture_file("empty_metatag_description.response"))
