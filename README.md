# MetaInspector [![Build Status](https://secure.travis-ci.org/jaimeiniesta/metainspector.png)](http://travis-ci.org/jaimeiniesta/metainspector) [![Dependency Status](https://gemnasium.com/jaimeiniesta/metainspector.png)](https://gemnasium.com/jaimeiniesta/metainspector) [![Code Climate](https://codeclimate.com/github/jaimeiniesta/metainspector/badges/gpa.svg)](https://codeclimate.com/github/jaimeiniesta/metainspector)

MetaInspector is a gem for web scraping purposes.

You give it an URL, and it lets you easily get its title, links, images, charset, description, keywords, meta tags...

## See it in action!

You can try MetaInspector live at this little demo: [https://metainspectordemo.herokuapp.com](https://metainspectordemo.herokuapp.com)

## Changes in 4.0

* The links API has been changed, now instead of `page.links`, `page.internal_links` and `page.external_links` we have:

```ruby
page.links.raw      # Returns all links found, unprocessed
page.links.all      # Returns all links found, unrelavitized and absolutified
page.links.http     # Returns all HTTP links found
page.links.non_http # Returns all non-HTTP links found
page.links.internal # Returns all internal HTTP links found
page.links.external # Returns all external HTTP links found
```

* The images API has been changed, now instead of `page.image` we have `page.images.best`, and instead of `page.favicon` we have `page.images.favicon`.

* Now `page.image` will return the first image in `page.images` if no OG or Twitter image found, instead of returning `nil`.

* You can now specify 2 different timeouts, `connection_timeout` and `read_timeout`, instead of the previous single `timeout`.

## Changes in 3.0

* The redirect API has been changed, now the `:allow_redirections` option will expect only a boolean, which by default is `true`. That is, no more specifying `:safe`, `:unsafe` or `:all`.
* We've dropped support for Ruby < 2.

Also, we've introduced a new feature:

* Persist cookies across redirects. Now MetaInspector will include the received cookies when following redirects. This fixes some cases where a redirect would fail, sometimes caught in a redirection loop.

## Installation

Install the gem from RubyGems:

```bash
gem install metainspector
```

If you're using it on a Rails application, just add it to your Gemfile and run `bundle install`

```ruby
gem 'metainspector'
```

This gem is tested on Ruby versions 2.0.0 and 2.1.3.

## Usage

Initialize a MetaInspector instance for an URL, like this:

```ruby
page = MetaInspector.new('http://sitevalidator.com')
```

If you don't include the scheme on the URL, http:// will be used by default:

```ruby
page = MetaInspector.new('sitevalidator.com')
```

You can also include the html which will be used as the document to scrape:

```ruby
page = MetaInspector.new("http://sitevalidator.com", :document => "<html><head><title>Hello From Passed Html</title><a href='/hello'>Hello link</a></head><body></body></html>")
```

## Accessing response status and headers

You can check the status and headers from the response like this:

```ruby
page.response.status  # 200
page.response.headers # { "server"=>"nginx", "content-type"=>"text/html; charset=utf-8", "cache-control"=>"must-revalidate, private, max-age=0", ... }
```

## Accessing scraped data

You can see the scraped data like this:

```ruby
page.url                 # URL of the page
page.scheme              # Scheme of the page (http, https)
page.host                # Hostname of the page (like, sitevalidator.com, without the scheme)
page.root_url            # Root url (scheme + host, like http://sitevalidator.com/)
page.title               # title of the page, as string
page.links.raw           # every link found, unprocessed
page.links.all           # every link found on the page as an absolute URL
page.links.http          # every HTTP link found
page.links.non_http      # every non-HTTP link found
page.links.internal      # every internal link found on the page as an absolute URL
page.links.external      # every external link found on the page as an absolute URL
page.meta['keywords']    # meta keywords, as string
page.meta['description'] # meta description, as string
page.description         # returns the meta description, or the first long paragraph if no meta description is found
page.images              # enumerable collection, with every img found on the page as an absolute URL
page.images.best         # Most relevant image, if defined with the og:image or twitter:image metatags. Fallback to the first page.images array element
page.images.favicon      # absolute URL to the favicon
page.feed                # Get rss or atom links in meta data fields as array
page.charset             # UTF-8
page.content_type        # content-type returned by the server when the url was requested
```

## Meta tags

When it comes to meta tags, you have several options:

```ruby
page.meta_tags  # Gives you all the meta tags by type:
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
```

As this method returns a hash, you can also take only the key that you need, like in:

```ruby
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
```

In most cases you will only be interested in the first occurrence of a meta tag, so you can
use the singular form of that method:

```ruby
page.meta_tag['name']   # Returns:
                        # {
                        #   'keywords'       => 'one, two, three',
                        #   'description'    => 'the description',
                        #   'author'         => 'Joe Sample',
                        #   'robots'         => 'index,follow',
                        #   'revisit'        => '15 days',
                        #   'dc.date.issued' => '2011-09-15'
                        # }
```

Or, as this is also a hash:

```ruby
page.meta_tag['name']['keywords']    # Returns 'one, two, three'
```

And finally, you can use the shorter `meta` method that will merge the different keys so you have
a simpler hash:

```ruby
page.meta   # Returns:
            #
            # {
            #   'keywords'            => 'one, two, three',
            #   'description'         => 'the description',
            #   'author'              => 'Joe Sample',
            #   'robots'              => 'index,follow',
            #   'revisit'             => '15 days',
            #   'dc.date.issued'      => '2011-09-15',
            #   'content-type'        => 'text/html; charset=UTF-8',
            #   'content-style-type'  => 'text/css',
            #   'og:title'            => 'An OG title',
            #   'og:type'             => 'website',
            #   'og:url'              => 'http://example.com/meta-tags',
            #   'og:image'            => 'http://example.com/rock.jpg',
            #   'og:image:width'      => '300',
            #   'og:image:height'     => '300',
            #   'charset'             => 'UTF-8'
            # }
```

This way, you can get most meta tags just like that:

```ruby
page.meta['author']     # Returns "Joe Sample"
```

Please be aware that all keys are converted to downcase, so it's `'dc.date.issued'` and not `'DC.date.issued'`.

## Other representations

You can also access most of the scraped data as a hash:

```ruby
page.to_hash    # { "url"   => "http://sitevalidator.com",
                    "title" => "MarkupValidator :: site-wide markup validation tool", ... }
```

The original document is accessible from:

```ruby
page.to_s         # A String with the contents of the HTML document
```

And the full scraped document is accessible from:

```ruby
page.parsed  # Nokogiri doc that you can use it to get any element from the page
```

## Options

### Timeout & Retries

You can specify 2 different timeouts when requesting a page:

* `connection_timeout` sets the maximum number of seconds to wait to get a connection to the page.
* `read_timeout` sets the maximum number of seconds to wait to read the page, once connected.

Both timeouts default to 20 seconds each.

You can also specify the number of `retries`, which defaults to 3.

For example, this will time out after 10 seconds waiting for a connection, or after 5 seconds waiting
to read its contents, and will retry 4 times:

```ruby
page = MetaInspector.new('www.google', :connection_timeout => 10, :read_timeout => 5, :retries => 4)
```

If MetaInspector fails to fetch the page after it has exhausted its retries,
it will raise `Faraday::TimeoutError`, which you can rescue in your
application code.

```ruby
begin
  page = MetaInspector.new(url)
rescue Faraday::TimeoutError
  enqueue_for_future_fetch_attempt(url)
  render_simple(url)
else
  render_rich(page)
end
```

### Redirections

By default, MetaInspector will follow redirects (up to a limit of 10).

If you want to disallow redirects, you can do it like this:

```ruby
page = MetaInspector.new('facebook.com', :allow_redirections => false)
```

### Headers

By default, the following headers are set:

```ruby
{'User-Agent' => "MetaInspector/#{MetaInspector::VERSION} (+https://github.com/jaimeiniesta/metainspector)"}
```

If you want to set custom headers then use the `headers` option:

```ruby
# Set the User-Agent header
page = MetaInspector.new('example.com', :headers => {'User-Agent' => 'My custom User-Agent'})
```

### HTML Content Only

MetaInspector will try to parse all URLs by default. If you want to raise an exception when trying to parse a non-html URL (one that has a content-type different than text/html), you can state it like this:

```ruby
page = MetaInspector.new('sitevalidator.com', :html_content_only => true)
```

This is useful when using MetaInspector on web spidering. Although on the initial URL you'll probably have an HTML URL, following links you may find yourself trying to parse non-html URLs.

```ruby
page = MetaInspector.new('http://example.com/image.png')
page.content_type  # "image/png"
page.description   # will returned a garbled string

page = MetaInspector.new('http://example.com/image.png', :html_content_only => true)
page.content_type  # "image/png"
page.description   # raises an exception
```

### URL Normalization

By default, URLs are normalized using the Addressable gem. For example:

```ruby
# Normalization will add a default scheme and a trailing slash...
page = MetaInspector.new('sitevalidator.com')
page.url # http://sitevalidator.com/

# ...and it will also convert international characters
page = MetaInspector.new('http://www.詹姆斯.com')
page.url # http://www.xn--8ws00zhy3a.com/
```

While this is generally useful, it can be [tricky](https://github.com/sporkmonger/addressable/issues/182) [sometimes](https://github.com/sporkmonger/addressable/issues/160).

You can disable URL normalization by passing the `normalize_url: false` option.

## Exception Handling

By default, MetaInspector will raise the exceptions found. We think that this is the safest default: in case the URL you're trying to scrape is unreachable, you should clearly be notified, and treat the exception as needed in your app.

However, if you prefer you can also set the `warn_level: :warn` option, so that exceptions found will just be warned on the standard output, instead of being raised.

You can also set the `warn_level: :store` option so that exceptions found will be silenced, and left for you to inspect on `page.exceptions`. You can also ask for `page.ok?`, wich will return `true` if no exceptions are stored.

You should avoid using the `:store` option, or use it wisely, as silencing errors can be problematic, it's always better to face the errors and treat them accordingly.

## Examples

You can find some sample scripts on the `examples` folder, including a basic scraping and a spider that will follow external links using a queue. What follows is an example of use from irb:

```ruby
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
```

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
