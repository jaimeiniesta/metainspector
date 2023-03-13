# A basic MetaInspector example for scraping a page
#
# Usage example:
#
#   ruby faraday_redirect_options.rb http://facebook.com

require '../lib/metainspector'
puts "Using MetaInspector #{MetaInspector::VERSION}"

# Get the starting URL
url = ARGV[0] || (puts "Enter an url"; gets.strip)

# redirect options to be passed along to Faraday::FollowRedirects::Middleware
redirects_opts = { limit: 5 }

# custom callback to handle the redirect links
redirects_opts[:callback] = proc do |old_response, new_response|
  puts "redirecting to : #{new_response.url}"
end

page = MetaInspector.new(url, faraday_options: { redirect: redirects_opts })

puts "\nScraping #{page.url} returned these results:"
puts "\nTITLE: #{page.title}"

puts "\nto_hash..."
puts page.to_hash
