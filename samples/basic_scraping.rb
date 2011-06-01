# Some basic MetaInspector samples

$: << File.join(File.dirname(__FILE__), "/../lib")
require 'meta_inspector'
require 'ap'

puts "Enter a valid http address to scrape it"
address = gets.strip
page = MetaInspector.new(address)
puts "...please wait while scraping the page..."

puts "Scraping #{page.url} returned these results:"
puts "TITLE: #{page.title}"
puts "META DESCRIPTION: #{page.meta_description}"
puts "META KEYWORDS: #{page.meta_keywords}"
puts "#{page.links.size} links found..."
page.links.each do |link|
  puts " ==> #{link}"
end

ap page.to_hash