# Some basic MetaInspector samples

require '../lib/metainspector.rb'

puts "Enter a valid http address to scrape it"
address = gets
page = MetaInspector.new(address)
puts "Scraping #{address}"
puts "...please wait..."

puts "Scraping #{page.address} returned these results:"
puts "TITLE: #{page.title}"
puts "DESCRIPTION: #{page.description}"
puts "KEYWORDS: #{page.keywords}"
puts "#{page.links.size} links found..."
page.links.each do |link|
  puts " ==> #{link}"
end