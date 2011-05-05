# A basic spider that will follow links on an infinite loop
require_relative '../lib/meta_inspector.rb'

q = Queue.new
visited_links=[]

puts "Enter a valid http address to spider it following external links"
address = gets.strip

page = MetaInspector.new(address)
q.push(address)

while q.size > 0
  visited_links << address = q.pop
  page = MetaInspector.new(address)
  puts "Spidering #{page.address}"

  puts "TITLE: #{page.title}"
  puts "META DESCRIPTION: #{page.meta_description}"
  puts "META KEYWORDS: #{page.meta_keywords}"
  puts "LINKS: #{page.links.size}"
  page.links.each do |link|
    if link[0..6] == 'http://' && !visited_links.include?(link)
      q.push(link)
    end
  end
  puts "#{visited_links.size} pages visited, #{q.size} pages on queue\n\n"
end