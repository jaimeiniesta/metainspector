# Some basic MetaInspector samples

$: << File.join(File.dirname(__FILE__), "/../lib")
require 'meta_inspector'
require 'ap'

puts "Enter a valid http url to scrape it"
url = gets.strip
page = MetaInspector.new(url)
puts "...please wait while scraping the page..."

puts "Scraping #{page.url} returned these results:"
puts "TITLE: #{page.title}"
puts "META DESCRIPTION: #{page.meta_description}"
puts "META KEYWORDS: #{page.meta_keywords}"
puts "#{page.links.size} links found..."
page.links.each do |link|
  puts " ==> #{link}"
end

puts "to_hash..."
ap page.to_hash