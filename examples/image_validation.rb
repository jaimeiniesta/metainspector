# Validate image candidates and omit invalid images from the results.
# Image downloads are bounded by max_downloads (default: 10); images beyond
# the limit remain in the results and are reported as not checked.
#
# Usage from the repository root:
#   bundle exec ruby examples/image_validation.rb <url> [max_downloads]

require_relative '../lib/metainspector'

VALIDITY = { true => 'valid', false => 'invalid', nil => 'not checked' }.freeze

url = ARGV[0] || (puts "Enter a url"; gets.strip)
max_downloads = Integer(ARGV[1] || 10)
page = MetaInspector.new(url, max_image_downloads: max_downloads,
  download_image_options: { reject_invalid_images: true }, fetch_all_image_meta: true)

page.images.with_metadata.each do |image|
  puts " ==> #{image[:url]}: #{VALIDITY[image[:valid]]}"
end

puts "#{page.images.to_a.size} images remain after validation..."
page.images.to_a.each do |image|
  puts " ==> #{image}"
end
puts "BEST: #{page.images.best}"
