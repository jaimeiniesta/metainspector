# List image candidates from img[src], img[srcset] and picture source[srcset].
#
# Usage from the repository root:
#   bundle exec ruby examples/responsive_images.rb <url>

require_relative '../lib/metainspector'

url = ARGV[0] || (puts "Enter a url"; gets.strip)
page = MetaInspector.new(url)

puts "#{page.images.to_a.size} image candidates found..."
page.images.to_a.each do |image|
  puts " ==> #{image}"
end
puts "BEST: #{page.images.best}"
