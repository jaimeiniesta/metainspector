# Download images to report dimensions, type and file size, largest first.
# Image downloads are bounded by max_downloads (default: 10).
#
# Usage from the repository root:
#   bundle exec ruby examples/image_details.rb <url> [max_downloads]

require_relative '../lib/metainspector'

url = ARGV[0] || (puts "Enter a url"; gets.strip)
max_downloads = Integer(ARGV[1] || 10)
page = MetaInspector.new(url, max_image_downloads: max_downloads)

page.images.with_details.each do |image|
  type = image[:type] || 'unknown type'
  size = image[:file_size] ? "#{image[:file_size]} bytes" : 'unknown size'
  puts "#{image[:url]} #{image[:width]}x#{image[:height]} #{type}, #{size}"
end
