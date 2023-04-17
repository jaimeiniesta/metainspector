# A MetaInspector example that runs a callback in between redirects.
# The callback raises an exception if the redirection points to a URL that resolves into a private IP address.
# This is one way of triggering a known security exploit called server-side request forgery (SSRF).
#
# To properly run this example you need a domain which redirects to a service like nip.io.
# The easiest way to achieve that is adding this line below to your /etc/hosts file:
# 10.0.0.0.nip.io domain_that_redirects_to_private_network.io
#
# Usage example:
#
#   ruby faraday_redirect_options.rb http://domain_that_redirects_to_private_network.io/

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
