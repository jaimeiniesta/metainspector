# Allow only explicitly trusted HTTPS hosts, including on redirects and image
# requests. A redirect callback can also observe redirects, but it is not a
# substitute for url_filter: it does not check the initial request.
#
# Usage from the examples directory:
#   bundle exec ruby faraday_redirect_options.rb https://example.com
#
# Choose hosts under your control for your application. A hostname allowlist
# alone does not prevent DNS rebinding or compromised DNS; use network egress
# restrictions as well when processing untrusted URLs.

require_relative '../lib/metainspector'

url = ARGV[0] || 'https://example.com'
allowed_hosts = %w[example.com www.example.com]

filter = proc do |uri|
  uri.scheme == 'https' && allowed_hosts.include?(uri.hostname)
end

redirect_options = {
  limit: 5,
  callback: proc do |old_response, new_request|
    puts "Redirect: #{old_response.url} -> #{new_request.url}"
  end
}

begin
  page = MetaInspector.new(url, url_filter: filter, faraday_options: { redirect: redirect_options })
  puts "Using MetaInspector #{MetaInspector::VERSION}"
  puts "Scraping #{page.url} returned title: #{page.title}"
rescue MetaInspector::RequestError => error
  warn error.message
end
