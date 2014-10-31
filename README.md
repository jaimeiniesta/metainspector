# MetaInspector [![Build Status](https://secure.travis-ci.org/jaimeiniesta/metainspector.png)](http://travis-ci.org/jaimeiniesta/metainspector) [![Dependency Status](https://gemnasium.com/jaimeiniesta/metainspector.png)](https://gemnasium.com/jaimeiniesta/metainspector)

MetaInspector is a gem for web scraping purposes.

You give it an URL, and it lets you easily get its title, links, images, charset, description, keywords, meta tags...

## See it in action!

You can try MetaInspector live at this little demo: [https://metainspectordemo.herokuapp.com](https://metainspectordemo.herokuapp.com)

## Changes in 3.0

This latest release introduces some backwards-incompatible changes, so we've decided to do a major version upgrade:

* The redirect API has been changed, now the `:allow_redirections` option will expect only a boolean, which by default is `true`. That is, no more specifying `:safe`, `:unsafe` or `:all`.
* We've dropped support for Ruby < 2.

Also, we've introduced a new feature:

* Persist cookies across redirects. Now MetaInspector will include the received cookies when following redirects. This fixes some cases where a redirect would fail, sometimes caught in a redirection loop.

## Installation

Install the gem from RubyGems:

    gem install metainspector

If you're using it on a Rails application, just add it to your Gemfile and run `bundle install`

    gem 'metainspector'

This gem is tested on Ruby versions 2.0.0 and 2.1.3.

## Usage

Initialize a MetaInspector instance for an URL, like this:

    page = MetaInspector.new('http://sitevalidator.com')

If you don't include the scheme on the URL, http:// will be used by default:

    page = MetaInspector.new('sitevalidator.com')

You can also include the html which will be used as the document to scrape:

    page = MetaInspector.new("http://sitevalidator.com", :document => "<html><head><title>Hello From Passed Html</title><a href='/hello'>Hello link</a></head><body></body></html>")

## Accessing response status and headers

You can check the status and headers from the response like this:

```ruby
page.response.status  # 200
page.response.headers # { "server"=>"nginx", "content-type"=>"text/html; charset=utf-8", "cache-control"=>"must-revalidate, private, max-age=0", ... }
```

## Accessing scraped data

You can see the scraped data like this:

    page.url                 # URL of the page
    page.scheme              # Scheme of the page (http, https)
    page.host                # Hostname of the page (like, sitevalidator.com, without the scheme)
    page.root_url            # Root url (scheme + host, like http://sitevalidator.com/)
    page.title               # title of the page, as string
    page.links               # array of strings, with every link found on the page as an absolute URL
    page.internal_links      # array of strings, with every internal link found on the page as an absolute URL
    page.external_links      # array of strings, with every external link found on the page as an absolute URL
    page.meta['keywords']    # meta keywords, as string
    page.meta['description'] # meta description, as string
    page.description         # returns the meta description, or the first long paragraph if no meta description is found
    page.image               # Most relevant image, if defined with the og:image or twitter:image metatags. Fallback to the first page.images array element
    page.images              # array of strings, with every img found on the page as an absolute URL
    page.feed                # Get rss or atom links in meta data fields as array
    page.charset             # UTF-8
    page.content_type        # content-type returned by the server when the url was requested
    page.favicon             # absolute URL to the favicon

## Meta tags

When it comes to meta tags, you have several options:

    page.meta_tags          # Gives you all the meta tags by type:
                            # (meta name, meta http-equiv, meta property and meta charset)
                            # As meta tags can be repeated (in the case of 'og:image', for example),
                            # the values returned will be arrays
                            #
                            # For example:
                            #
                            # {
                                'name' => {
                                            'keywords'       => ['one, two, three'],
                                            'description'    => ['the description'],
                                            'author'         => ['Joe Sample'],
                                            'robots'         => ['index,follow'],
                                            'revisit'        => ['15 days'],
                                            'dc.date.issued' => ['2011-09-15']
                                           },

                                'http-equiv' => {
                                                  'content-type'        => ['text/html; charset=UTF-8'],
                                                  'content-style-type'  => ['text/css']
                                                },

                                'property' => {
                                                'og:title'        => ['An OG title'],
                                                'og:type'         => ['website'],
                                                'og:url'          => ['http://example.com/meta-tags'],
                                                'og:image'        => ['http://example.com/rock.jpg',
                                                                      'http://example.com/rock2.jpg',
                                                                      'http://example.com/rock3.jpg'],
                                                'og:image:width'  => ['300'],
                                                'og:image:height' => ['300', '1000']
                                              },

                                'charset' => ['UTF-8']
                              }

As this method returns a hash, you can also take only the key that you need, like in:

    page.meta_tags['property']  # Returns:
                                # {
                                #   'og:title'        => ['An OG title'],
                                #   'og:type'         => ['website'],
                                #   'og:url'          => ['http://example.com/meta-tags'],
                                #   'og:image'        => ['http://example.com/rock.jpg',
                                #                         'http://example.com/rock2.jpg',
                                #                         'http://example.com/rock3.jpg'],
                                #   'og:image:width'  => ['300'],
                                #   'og:image:height' => ['300', '1000']
                                # }

In most cases you will only be interested in the first occurrence of a meta tag, so you can
use the singular form of that method:

    page.meta_tag['name']  # Returns:
                           # {
                           #   'keywords'       => 'one, two, three',
                           #   'description'    => 'the description',
                           #   'author'         => 'Joe Sample',
                           #   'robots'         => 'index,follow',
                           #   'revisit'        => '15 days',
                           #   'dc.date.issued' => '2011-09-15'
                           #  }

Or, as this is also a hash:

    page.meta_tag['name']['keywords']    # Returns 'one, two, three'

And finally, you can use the shorter `meta` method that will merge the different keys so you have
a simpler hash:

    page.meta       # Returns:
                    #
                    # {
                    #     'keywords'            => 'one, two, three',
                    #     'description'         => 'the description',
                    #     'author'              => 'Joe Sample',
                    #     'robots'              => 'index,follow',
                    #     'revisit'             => '15 days',
                    #     'dc.date.issued'      => '2011-09-15',
                    #     'content-type'        => 'text/html; charset=UTF-8',
                    #     'content-style-type'  => 'text/css',
                    #     'og:title'            => 'An OG title',
                    #     'og:type'             => 'website',
                    #     'og:url'              => 'http://example.com/meta-tags',
                    #     'og:image'            => 'http://example.com/rock.jpg',
                    #     'og:image:width'      => '300',
                    #     'og:image:height'     => '300',
                    #     'charset'             => 'UTF-8'
                    #   }

This way, you can get most meta tags just like that:

    page.meta['author']     # Returns "Joe Sample"

Please be aware that all keys are converted to downcase, so it's `'dc.date.issued'` and not `'DC.date.issued'`.

## Other representations

You can also access most of the scraped data as a hash:

    page.to_hash  # { "url"   => "http://sitevalidator.com",
                      "title" => "MarkupValidator :: site-wide markup validation tool", ... }

The original document is accessible from:

    page.to_s         # A String with the contents of the HTML document

And the full scraped document is accessible from:

    page.parsed  # Nokogiri doc that you can use it to get any element from the page

## Options

### Timeout & Retries

By default, MetaInspector times out after 20 seconds of waiting for a page to respond,
and it will retry fetching the page 3 times.
You can specify different values for both of these, like this:

    # timeout after 5 seconds, retry 4 times
    page = MetaInspector.new('sitevalidator.com', :timeout => 5, :retries => 4)

If MetaInspector fails to fetch the page after it has exhausted its retries,
it will raise `MetaInspector::Request::TimeoutError`, which you can rescue in your
application code.

    begin
      data = MetaInspector.new(url)
    rescue MetaInspector::Request::TimeoutError
      enqueue_for_future_fetch_attempt(url)
      render_simple(url)
    rescue
      log_fetch_error($!)
      render_simple(url)
    else
      render_rich(data)
    end

### Redirections

By default, MetaInspector will follow redirects (up to a limit of 10).

If you want to disallow redirects, you can do it like this:

    page = MetaInspector.new('facebook.com', :allow_redirections => false)

### Headers

By default, the following headers are set:

    {'User-Agent' => "MetaInspector/#{MetaInspector::VERSION} (+https://github.com/jaimeiniesta/metainspector)"}

If you want to set custom headers then use the `headers` option:

     # Set the User-Agent header
     page = MetaInspector.new('example.com', :headers => {'User-Agent' => 'My custom User-Agent'})

### HTML Content Only

MetaInspector will try to parse all URLs by default. If you want to raise an exception when trying to parse a non-html URL (one that has a content-type different than text/html), you can state it like this:

    page = MetaInspector.new('sitevalidator.com', :html_content_only => true)

This is useful when using MetaInspector on web spidering. Although on the initial URL you'll probably have an HTML URL, following links you may find yourself trying to parse non-html URLs.

    page = MetaInspector.new('http://example.com/image.png')
    page.content_type  # "image/png"
    page.description   # will returned a garbled string

    page = MetaInspector.new('http://example.com/image.png', :html_content_only => true)
    page.content_type  # "image/png"
    page.description   # raises an exception

## Exception handling

By default, MetaInspector will raise the exceptions found. We think that this is the safest default: in case the URL you're trying to scrape is unreachable, you should clearly be notified, and treat the exception as needed in your app.

However, if you prefer you can also set the `warn_level: :warn` option, so that exceptions found will just be warned on the standard output, instead of being raised.

You can also set the `warn_level: :store` option so that exceptions found will be silenced, and left for you to inspect on `page.exceptions`. You can also ask for `page.ok?`, wich will return `true` if no exceptions are stored.

You should avoid using the `:store` option, or use it wisely, as silencing errors can be problematic, it's always better to face the errors and treat them accordingly.

## Examples

You can find some sample scripts on the `examples` folder, including a basic scraping and a spider that will follow external links using a queue. What follows is an example of use from irb:

    $ irb
    >> require 'metainspector'
    => true

    >> page = MetaInspector.new('http://sitevalidator.com')
    => #<MetaInspector:0x11330c0 @url="http://sitevalidator.com">

    >> page.title
    => "MarkupValidator :: site-wide markup validation tool"

    >> page.meta['description']
    => "Site-wide markup validation tool. Validate the markup of your whole site with just one click."

    >> page.meta['keywords']
    => "html, markup, validation, validator, tool, w3c, development, standards, free"

    >> page.links.size
    => 15

    >> page.links[4]
    => "/plans-and-pricing"

## ZOMG Fork! Thank you!

You're welcome to fork this project and send pull requests. Just remember to include specs.

Thanks to all the contributors:

[https://github.com/jaimeiniesta/metainspector/graphs/contributors](https://github.com/jaimeiniesta/metainspector/graphs/contributors)

You are more than welcome to come chat with us on our [Gitter room](https://gitter.im/jaimeiniesta/metainspector) and [Google group](https://groups.google.com/forum/#!forum/metainspector).

## Related projects

* [go-metainspector](https://github.com/fern4lvarez/go-metainspector), a port of MetaInspector for Go.
* [Node-MetaInspector](https://github.com/gabceb/node-metainspector), a port of MetaInspector for Node.

## License
MetaInspector is released under the [MIT license](MIT-LICENSE).
