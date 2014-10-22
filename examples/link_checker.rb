# A basic spider that will follow internal links, checking broken links
#
# Usage example:
#
#   ruby link_checker.rb alazan.com

require 'metainspector'

class BrokenLinkChecker
  attr_reader :broken

  def initialize(url)
    @url      = url
    @queue    = []
    @visited  = []
    @ok       = []
    @broken   = {}

    check
  end

  def report
    puts "\n#{@broken.size} broken links found."

    @broken.each do |link, from|
      puts "\n#{link} linked from"
      from.each do |origin|
        puts " - #{origin}"
      end
    end
  end

  private

  def check
    # Resolve initial redirections
    page = MetaInspector.new(@url)

    # Push this initial URL to the queue
    @queue.push(page.url)

    while @queue.any?
      url = @queue.pop

      page = MetaInspector.new(url, :warn_level => :store)

      if page.ok?
        # Gets all HTTP links
        page.links.select {|l| l =~ /^http(s)?:\/\//i}.each do |link|
          check_status(link, page.url)
        end
      end

      @visited.push(page.url)

      page.internal_links.each do |link|
        @queue.push(link) unless @visited.include?(link) || @broken.include?(link) || @queue.include?(link)
      end

      puts "#{'%3s' % @visited.size} pages visited, #{'%3s' % @queue.size} pages on queue, #{'%2s' % @broken.size} broken links"
    end
  end

  # Checks the response status of the linked_url and stores it on the ok or broken collections
  def check_status(linked_url, from_url)
    if @broken.keys.include?(linked_url)
      # This was already known to be broken, we add another origin
      @broken[linked_url] << from_url
    else
      if !@ok.include?(linked_url)
        # We still don't know about this link status, so we check it now
        if reachable?(linked_url)
          @ok << linked_url
        else
          @broken[linked_url] = [from_url]
        end
      end
    end
  end

  # A page is reachable if its response status is less than 400
  # In the case of exceptions, like timeouts or server connection errors,
  # we consider it unreachable
  def reachable?(url)
    page = MetaInspector.new(url)

    if page.response.status < 400
      true
    else
      false
    end
  rescue Exception => e
    false
  end
end

# Get the starting URL
url = ARGV[0] || (puts "Enter a starting url"; gets.strip)

BrokenLinkChecker.new(url).report
