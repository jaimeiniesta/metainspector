# A basic MetaInspector example for scraping a page
#
# Usage example:
#
#   ruby faraday_redirect_options.rb http://facebook.com

require 'resolv'
require '../lib/metainspector'
puts "Using MetaInspector #{MetaInspector::VERSION}"

# Get the starting URL
url = ARGV[0] || (puts "Enter an url"; gets.strip)

# redirect options to be passed along to Faraday::FollowRedirects::Middleware
redirects_opts = {
  limit: 5,
  callback: proc do |_old_response, new_response|
    ip_address = Resolv.getaddress(new_response.url.host)
    raise 'Invalid address' if IPAddr.new(ip_address).private?
  end
}

begin
  page = MetaInspector.new(url, faraday_options: { redirect: redirects_opts })
rescue StandardError => e
  puts e.message
else
  puts "\nScraping #{page.url} returned these results:"
  puts "\nTITLE: #{page.title}"

  puts "\nto_hash..."
  puts page.to_hash
end
