# A basic MetaInspector example for scraping a page
#
# Usage example:
#
#   ruby basic_scraping.rb jaimeiniesta.com

require 'metainspector'

# Get the starting URL
url = ARGV[0] || (puts "Enter an url"; gets.strip)

page = MetaInspector.new(url)

puts "Scraping #{page.url} returned these results:"
puts "TITLE: #{page.title}"
puts "META DESCRIPTION: #{page.meta['description']}"
puts "META KEYWORDS: #{page.meta['keywords']}"
puts "#{page.links.size} links found..."
page.links.each do |link|
  puts " ==> #{link}"
end

puts "to_hash..."
puts page.to_hash
