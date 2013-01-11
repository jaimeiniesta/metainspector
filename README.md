# MetaInspector [![Build Status](https://secure.travis-ci.org/jaimeiniesta/metainspector.png)](http://travis-ci.org/jaimeiniesta/metainspector) [![Dependency Status](https://gemnasium.com/jaimeiniesta/metainspector.png)](https://gemnasium.com/jaimeiniesta/metainspector)

MetaInspector is a gem for web scraping purposes. You give it an URL, and it lets you easily get its title, links, images, charset, description, keywords, meta tags...

## See it in action!

You can try MetaInspector live at this little demo: [https://metainspectordemo.herokuapp.com](https://metainspectordemo.herokuapp.com)

## Installation

Install the gem from RubyGems:

    gem install metainspector
    
If you're using it on a Rails application, just add it to your Gemfile and run `bundle install`

    gem 'metainspector'

This gem is tested on Ruby versions 1.8.7, 1.9.2 and 1.9.3.

## Usage

Initialize a MetaInspector instance for an URL, like this:

    page = MetaInspector.new('http://markupvalidator.com')

If you don't include the scheme on the URL, http:// will be used by default:

    page = MetaInspector.new('markupvalidator.com')

You can also include the html which will be used as the document to scrape:

    page = MetaInspector.new("http://markupvalidator.com", :document => "<html><head><title>Hello From Passed Html</title><a href='/hello'>Hello link</a></head><body></body></html>")

## Accessing scraped data

Then you can see the scraped data like this:

    page.url                # URL of the page
    page.scheme             # Scheme of the page (http, https)
    page.host               # Hostname of the page (like, markupvalidator.com, without the scheme)
    page.root_url           # Root url (scheme + host, like http://markupvalidator.com/)
    page.title              # title of the page, as string
    page.links              # array of strings, with every link found on the page as an absolute URL
    page.internal_links     # array of strings, with every internal link found on the page as an absolute URL
    page.external_links     # array of strings, with every external link found on the page as an absolute URL
    page.meta_description   # meta description, as string
    page.description        # returns the meta description, or the first long paragraph if no meta description is found
    page.meta_keywords      # meta keywords, as string
    page.image              # Most relevant image, if defined with og:image
    page.images             # array of strings, with every img found on the page as an absolute URL
    page.feed               # Get rss or atom links in meta data fields as array
    page.meta_og_title      # opengraph title
    page.meta_og_image      # opengraph image
    page.charset            # UTF-8
    page.content_type       # content-type returned by the server when the url was requested

MetaInspector uses dynamic methods for meta_tag discovery, so all these will work, and will be converted to a search of a meta tag by the corresponding name, and return its content attribute

    page.meta_description   # <meta name="description" content="..." />
    page.meta_keywords      # <meta name="keywords" content="..." />
    page.meta_robots        # <meta name="robots" content="..." />
    page.meta_generator     # <meta name="generator" content="..." />

It will also work for the meta tags of the form <meta http-equiv="name" ... />, like the following:

    page.meta_content_language  # <meta http-equiv="content-language" content="..." />
    page.meta_Content_Type      # <meta http-equiv="Content-Type" content="..." />

Please notice that MetaInspector is case sensitive, so `page.meta_Content_Type` is not the same as `page.meta_content_type`

You can also access most of the scraped data as a hash:

    page.to_hash  # { "url"   => "http://markupvalidator.com",
                      "title" => "MarkupValidator :: site-wide markup validation tool", ... }

The original document is accessible from:

    page.document         # A String with the contents of the HTML document

And the full scraped document is accessible from:

    page.parsed_document  # Nokogiri doc that you can use it to get any element from the page
    
## Options

### Timeout

By default, MetaInspector times out after 20 seconds of waiting for a page to respond.
You can set a different timeout with a second parameter, like this:

    page = MetaInspector.new('markupvalidator.com', :timeout => 5) # 5 seconds timeout

### Redirections

MetaInspector allows safe redirects from http to https (for example, [http://github.com](http://github.com) => [https://github.com](https://github.com)) by default. With the option `:allow_safe_redirections => false`, it will throw exceptions on such redirects.

    page = MetaInspector.new('facebook.com', :allow_safe_redirections => false)

To enable unsafe redirects from https to http (like, [https://example.com](https://example.com) => [http://example.com](http://example.com)) you can pass the option `:allow_unsafe_redirections => true`. If this option is not specified or is false an exception is thrown on such redirects.

    page = MetaInspector.new('facebook.com', :allow_unsafe_redirections => true)

### HTML Content Only

MetaInspector will try to parse all URLs by default. If you want to raise an error when trying to parse a non-html URL (one that has a content-type different than text/html), you can state it like this:

    page = MetaInspector.new('markupvalidator.com', :html_content_only => true)

This is useful when using MetaInspector on web spidering. Although on the initial URL you'll probably have an HTML URL, following links you may find yourself trying to parse non-html URLs.

    page = MetaInspector.new('http://example.com/image.png')
    page.title         # returns ""
    page.content_type  # "image/png"
    page.ok?           # true

    page = MetaInspector.new('http://example.com/image.png', :html_content_only => true)
    page.title         # returns nil
    page.content_type  # "image/png"
    page.ok?           # false 
    page.errors.first  # "Scraping exception: The url provided contains image/png content instead of text/html content"

## Error handling

You can check if the page has been succesfully parsed with:

    page.ok?     # Will return true if everything looks OK

In case there have been any errors, you can check them with:

    page.errors  # Will return an array with the error messages

If you also want to see the errors on console, you can initialize MetaInspector with the verbose option like that:

    page = MetaInspector.new('http://example.com', :verbose => true)

## Examples

You can find some sample scripts on the samples folder, including a basic scraping and a spider that will follow external links using a queue. What follows is an example of use from irb:

    $ irb
    >> require 'metainspector'
    => true
  
    >> page = MetaInspector.new('http://markupvalidator.com')
    => #<MetaInspector:0x11330c0 @url="http://markupvalidator.com">
  
    >> page.title
    => "MarkupValidator :: site-wide markup validation tool"
  
    >> page.meta_description
    => "Site-wide markup validation tool. Validate the markup of your whole site with just one click."
  
    >> page.meta_keywords
    => "html, markup, validation, validator, tool, w3c, development, standards, free"
  
    >> page.links.size
    => 15
  
    >> page.links[4]
    => "/plans-and-pricing"
  
    >> page.document.class
    => String
  
    >> page.parsed_document.class
    => Nokogiri::HTML::Document

## ZOMG Fork! Thank you!

You're welcome to fork this project and send pull requests. Just remember to include specs.

Thanks to all the contributors:

[https://github.com/jaimeiniesta/metainspector/graphs/contributors](https://github.com/jaimeiniesta/metainspector/graphs/contributors)

Copyright (c) 2009-2012 Jaime Iniesta, released under the MIT license
