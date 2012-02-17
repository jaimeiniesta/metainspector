# A basic spider that will follow links on an infinite loop
$: << File.join(File.dirname(__FILE__), "/../lib")
require 'rubygems'
require 'meta_inspector'

q = Queue.new
visited_links=[]

puts "Enter a valid http url to spider it following external links"
url = gets.strip

page = MetaInspector.new(url)
q.push(url)

while q.size > 0
  visited_links << url = q.pop
  page = MetaInspector.new(url)
  puts "Spidering #{page.url}"

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