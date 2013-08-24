# -*- encoding: utf-8 -*-

require 'open-uri'
require 'open_uri_redirections'
require 'addressable/uri'
require 'nokogiri'
require 'hashie/rash'
require 'timeout'

# MetaInspector provides an easy way to scrape web pages and get its elements
module MetaInspector
  class Scraper
    attr_reader :url, :scheme, :host, :root_url, :errors, :content_type, :timeout, :html_content_only
    attr_reader :allow_redirections, :verbose

    # Initializes a new instance of MetaInspector, setting the URL to the one given
    # Options:
    # => timeout: defaults to 20 seconds
    # => html_content_type_only: if an exception should be raised if request content-type is not text/html. Defaults to false
    # => allow_redirections: when :safe, allows HTTP => HTTPS redirections. When :all, it also allows HTTPS => HTTP
    # => document: the html of the url as a string
    # => verbose: if the errors should be logged to the screen
    def initialize(url, options = {})
      options   = defaults.merge(options)

      @url      = with_default_scheme(normalize_url(url))
      @scheme   = URI.parse(@url).scheme
      @host     = URI.parse(@url).host
      @root_url = "#{@scheme}://#{@host}/"
      @timeout  = options[:timeout]
      @data     = Hashie::Rash.new
      @errors   = []
      @html_content_only  = options[:html_content_only]
      @allow_redirections = options[:allow_redirections]
      @verbose            = options[:verbose]
      @document           = options[:document]
    end

    # Returns the parsed document title, from the content of the <title> tag.
    # This is not the same as the meta_title tag
    def title
      @title ||= parsed_document.css('title').inner_text rescue nil
    end

    # A description getter that first checks for a meta description and if not present will
    # guess by looking at the first paragraph with more than 120 characters
    def description
      meta_description.nil? ? secondary_description : meta_description
    end

    # Links found on the page, as absolute URLs
    def links
      @links ||= parsed_links.map{ |l| absolutify_url(unrelativize_url(l)) }.compact.uniq
    end

    # Internal links found on the page, as absolute URLs
    def internal_links
      @internal_links ||= links.select {|link| host_from_url(link) == host }
    end

    # External links found on the page, as absolute URLs
    def external_links
      @external_links ||= links.select {|link| host_from_url(link) != host }
    end

    # Images found on the page, as absolute URLs
    def images
      @images ||= parsed_images.map{ |i| absolutify_url(i) }
    end

    # Returns the parsed image from Facebook's open graph property tags
    # Most all major websites now define this property and is usually very relevant
    # See doc at http://developers.facebook.com/docs/opengraph/
    def image
      meta_og_image || meta_twitter_image
    end

    # Returns the parsed document meta rss link
    def feed
      @feed ||= (parsed_feed('rss') || parsed_feed('atom'))
    end

    # Returns the charset from the meta tags, looking for it in the following order:
    # <meta charset='utf-8' />
    # <meta http-equiv="Content-Type" content="text/html; charset=windows-1252" />
    def charset
      @charset ||= (charset_from_meta_charset || charset_from_content_type)
    end

    # Returns all parsed data as a nested Hash
    def to_hash
      scrape_meta_data

      {
        'url' => url,
        'title' => title,
        'links' => links,
        'internal_links' => internal_links,
        'external_links' => external_links,
        'images' => images,
        'charset' => charset,
        'feed' => feed,
        'content_type' => content_type
      }.merge @data.to_hash
    end

    # Returns the whole parsed document
    def parsed_document
      @parsed_document ||= Nokogiri::HTML(document)
      rescue Exception => e
        add_fatal_error "Parsing exception: #{e.message}"
    end

    # Returns the original, unparsed document
    def document
      @document ||= if html_content_only && content_type != "text/html"
                      raise "The url provided contains #{content_type} content instead of text/html content" and nil
                    else
                      request.read
                    end
      rescue Exception => e
        add_fatal_error "Scraping exception: #{e.message}"
    end

    # Returns the content_type of the fetched document
    def content_type
      @content_type ||= request.content_type
    end

    # Returns true if there are no errors
    def ok?
      errors.empty?
    end

    private

    def defaults
      {
        :timeout                    => 20,
        :html_content_only          => false,
        :verbose                    => false
      }
    end

    # Scrapers for all meta_tags in the form of "meta_name" are automatically defined. This has been tested for
    # meta name: keywords, description, robots, generator
    # meta http-equiv: content-language, Content-Type
    #
    # It will first try with meta name="..." and if nothing found,
    # with meta http-equiv="...", substituting "_" by "-"
    # TODO: define respond_to? to return true on the meta_name methods
    def method_missing(method_name)
      if method_name.to_s =~ /^meta_(.*)/
        key = $1
        key = "og:#{$1}".gsub("_",":") if key =~ /^og_(.*)/ # special treatment for og:
        key = "twitter:#{$1}".gsub("_",":") if key =~ /^twitter_(.*)/ # special treatment for twitter:

        scrape_meta_data

        @data.meta.name && (@data.meta.name[key.downcase]) || (@data.meta.property && @data.meta.property[key.downcase])
      else
        super
      end
    end

    # Makes the request to the server
    def request
      Timeout::timeout(timeout) { @request ||= open(url, {:allow_redirections => allow_redirections}) }

      rescue TimeoutError
        add_fatal_error 'Timeout!!!'
      rescue SocketError
        add_fatal_error 'Socket error: The url provided does not exist or is temporarily unavailable'
      rescue Exception => e
        add_fatal_error "Scraping exception: #{e.message}"
    end

    # Scrapes all meta tags found
    def scrape_meta_data
      unless @data.meta
        @data.meta!.name!
        @data.meta!.property!
        parsed_document.xpath("//meta").each do |element|
          get_meta_name_or_property(element)
        end
      end
    end

    # Store meta tag value, looking at meta name or meta property
    def get_meta_name_or_property(element)
      name_or_property = element.attributes["name"] ? "name" : (element.attributes["property"] ? "property" : nil)
      content_or_value = element.attributes["content"] ? "content" : (element.attributes["value"] ? "value" : nil)
      
      if !name_or_property.nil? && !content_or_value.nil?
        @data.meta.name[element.attributes[name_or_property].value.downcase] = element.attributes[content_or_value].value
      end
    end

    def parsed_feed(format)
      feed = parsed_document.search("//link[@type='application/#{format}+xml']").first
      feed ? absolutify_url(feed.attributes['href'].value) : nil
    end

    def parsed_links
      @parsed_links ||= cleanup_nokogiri_values(parsed_document.search("//a/@href"))
    end

    def parsed_images
      @parsed_images ||= cleanup_nokogiri_values(parsed_document.search('//img/@src'))
    end

    # Takes a nokogiri search result, strips the values, rejects the empty ones, and removes duplicates
    def cleanup_nokogiri_values(results)
      results.map { |a| a.value.strip }.reject { |s| s.empty? }.uniq
    end

    # Stores the error for later inspection
    def add_fatal_error(error)
      warn error if verbose
      @errors << error
    end

    # Normalize url to deal with characters that should be encodes, add trailing slash, convert to downcase...
    def normalize_url(url)
      Addressable::URI.parse(url).normalize.to_s
    end

    # Adds 'http' as default scheme, if there if none
    def with_default_scheme(url)
      URI.parse(url).scheme.nil? ? 'http://' + url : url
    end

    # Convert a relative url like "/users" to an absolute one like "http://example.com/users"
    # Respecting already absolute URLs like the ones starting with http:, ftp:, telnet:, mailto:, javascript: ...
    def absolutify_url(uri)
      if uri =~ /^\w*\:/i
        normalize_url(uri)
      else
        Addressable::URI.join(@url, uri).normalize.to_s
      end
    rescue URI::InvalidURIError, Addressable::URI::InvalidURIError => e
      add_fatal_error "Link parsing exception: #{e.message}" and nil
    end

    # Convert a protocol-relative url to its full form, depending on the scheme of the page that contains it
    def unrelativize_url(url)
      url =~ /^\/\// ? "#{scheme}://#{url[2..-1]}" : url
    end

    # Extracts the host from a given URL
    def host_from_url(url)
      URI.parse(url).host
    rescue URI::InvalidURIError, URI::InvalidComponentError, Addressable::URI::InvalidURIError => e
      add_fatal_error "Link parsing exception: #{e.message}" and nil
    end

    # Look for the first <p> block with 120 characters or more
    def secondary_description
      first_long_paragraph = parsed_document.search('//p[string-length() >= 120]').first
      first_long_paragraph ? first_long_paragraph.text : ''
    end

    def charset_from_meta_charset
      parsed_document.css("meta[charset]")[0].attributes['charset'].value rescue nil
    end

    def charset_from_content_type
      parsed_document.css("meta[http-equiv='Content-Type']")[0].attributes['content'].value.split(";")[1].split("=")[1] rescue nil
    end
  end
end
