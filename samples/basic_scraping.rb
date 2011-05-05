# Some basic MetaInspector samples

require_relative '../lib/meta_inspector.rb'

puts "Enter a valid http address to scrape it"
address = gets.strip
page = MetaInspector.new(address)
puts "...please wait while scraping the page..."

puts "Scraping #{page.address} returned these results:"
puts "TITLE: #{page.title}"
puts "META DESCRIPTION: #{page.meta_description}"
puts "META KEYWORDS: #{page.meta_keywords}"
puts "#{page.links.size} links found..."
page.links.each do |link|
  puts " ==> #{link}"
end