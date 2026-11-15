# List iframe attributes and resolved source URLs. Embedded documents are not downloaded.
#
# Usage from the repository root:
#   bundle exec ruby examples/iframes.rb <url>

require_relative '../lib/metainspector'

url = ARGV[0] || (puts "Enter a url"; gets.strip)
page = MetaInspector.new(url)

puts "#{page.iframes.size} iframes found..."
page.iframes.zip(page.iframe_sources).each do |attributes, source|
  puts " ==> #{source || '(no source)'}"
  puts attributes.map { |name, value| "#{name}=#{value.inspect}" }.join(' ')
end
