# Skip HTML larger than max_bytes (default: 2 MiB).
# The limit applies after download and does not bound parse time.
#
# Usage from the repository root:
#   bundle exec ruby examples/html_size_limit.rb <url> [max_bytes]

require_relative '../lib/metainspector'

url = ARGV[0] || (puts "Enter a url"; gets.strip)
max_bytes = Integer(ARGV[1] || 2 * 1024 * 1024)

begin
  page = MetaInspector.new(url, max_html_bytes: max_bytes)
  puts "TITLE: #{page.title}"
rescue MetaInspector::ParserError => error
  puts "Skipped: #{error.message}"
end
