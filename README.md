# MetaInspector
[![Gem Version](https://badge.fury.io/rb/metainspector.svg)](http://badge.fury.io/rb/metainspector) [![CircleCI](https://circleci.com/gh/jaimeiniesta/metainspector.svg?style=svg)](https://circleci.com/gh/jaimeiniesta/metainspector) [![Mentioned in Awesome Ruby](https://awesome.re/mentioned-badge.svg)](https://github.com/markets/awesome-ruby)

MetaInspector is a gem for web scraping purposes.

You give it an URL, and it lets you easily get its title, links, images, charset, description, keywords, meta tags...

## Installation

Install the gem from RubyGems:

```bash
gem install metainspector
```

If you're using it on a Rails application, just add it to your Gemfile and run `bundle install`

```ruby
gem 'metainspector'
```

Supported Ruby versions are defined in [`.circleci/config.yml`](.circleci/config.yml).

## Supporting MetaInspector

MetaInspector has been downloaded more than 4 million times via RubyGems.org and has more than 1K stars on GitHub.

If you're using MetaInspector, please consider giving back to help ensure its continued development. You can support the project by becoming a sponsor on [GitHub Sponsors](https://github.com/sponsors/jaimeiniesta): pick the tier that suits you, either as an individual or on behalf of your company.

## Usage

Initialize a MetaInspector instance for an URL, like this:

```ruby
page = MetaInspector.new('https://github.com')
```

If you don't include the scheme on the URL, http:// will be used by default:

```ruby
page = MetaInspector.new('github.com')
```

You can also include the html which will be used as the document to scrape:

```ruby
page = MetaInspector.new("https://github.com",
                         :document => "<html>...</html>")
```

## Accessing response

You can check the status and headers from the response like this:

```ruby
page.response.status  # 200
page.response.headers # { "server"=>"nginx", "content-type"=>"text/html; charset=utf-8",
                      #   "cache-control"=>"must-revalidate, private, max-age=0", ... }
```

## Accessing scraped data

### URL

```ruby
page.url                 # URL of the page
page.tracked?            # returns true if the url contains known tracking parameters
page.untracked_url       # returns the url with the known tracking parameters removed
page.untrack!            # removes the known tracking parameters from the url
page.scheme              # Scheme of the page (http, https)
page.host                # Hostname of the page (like, github.com, without the scheme)
page.root_url            # Root url (scheme + host, like https://github.com/)
```

### Head links

```ruby
page.head_links          # an array of hashes of all head/links
page.stylesheets         # an array of hashes of all head/links where rel='stylesheet'
page.canonicals          # an array of hashes of all head/links where rel='canonical'
page.feeds               # Get rss or atom links in meta data fields as array of hash in the form { href: "...", title: "...", type: "..." }
```

### Texts

```ruby
page.language            # declared language from the root <html lang="..."> attribute
page.title               # title of the page from the head section, as string
page.best_title          # best title of the page, from a selection of candidates
page.author              # author of the page from the meta author tag
page.best_author         # best author of the page, from a selection of candidates
page.description         # returns the meta description
page.best_description    # returns the first non-empty description between the following candidates: standard meta description, og:description, twitter:description, the first long paragraph
page.h1                  # returns h1 text array
page.h2                  # returns h2 text array
page.h3                  # returns h3 text array
page.h4                  # returns h4 text array
page.h5                  # returns h5 text array
page.h6                  # returns h6 text array
```

`language` trims surrounding whitespace and preserves the declared value, including
capitalization and regional tags such as `en-US`. It returns `nil` when the `lang`
attribute is missing, empty, or whitespace-only. It does not infer language from
the page content or other attributes. The value is also included in `to_hash`
under the `"language"` key.

`best_title` selects the first non-empty value from the standard `title` meta tag,
`og:title`, the head `<title>`, a body `<title>`, the first `<h1>`, and finally
`parsely-title`.

`best_author` selects the first non-empty value from the standard `author` meta tag,
the first link with `rel="author"`, the first `<address>`, `twitter:creator`, and
finally `parsely-author`. Both methods trim and collapse whitespace in their results.

### Links

```ruby
page.links.raw           # every link found, unprocessed
page.links.all           # every link found on the page as an absolute URL
page.links.http          # every HTTP link found
page.links.non_http      # every non-HTTP link found
page.links.internal      # every internal link found on the page as an absolute URL
page.links.external      # every external link found on the page as an absolute URL
```

### Images

```ruby
page.images              # enumerable collection, with every img found on the page as an absolute URL
page.images.with_size    # a sorted array (by descending area) of [image_url, width, height]
page.images.best         # Most relevant image from og:image, twitter:image, or parsely-image-url; falls back to page.images.largest
page.images.favicon      # absolute URL to the favicon
```

`images.owner_suggested` tries `og:image`, `twitter:image`, and `parsely-image-url`
in that order, skipping empty or whitespace-only values. Relative image URLs are
resolved against the document's base URL. `images.best` uses this suggested image
before falling back to the largest suitable image on the page.

### Iframes

```ruby
page.iframes             # array of attribute hashes, one per iframe
page.iframe_sources      # resolved source URLs, one per iframe
```

Each hash contains the original attributes of an `<iframe>`, keyed by symbol;
for example, `src` remains as written and boolean attributes such as
`allowfullscreen` have an empty string value. HTML entities are decoded by the parser.
Both arrays follow document order and retain duplicates. `iframe_sources` strips
surrounding whitespace and resolves each `src` against the document's base URL
without normalizing it. It contains `nil` for a missing, blank, or unresolvable
source. These methods inspect iframe elements in the page; they do not download
or inspect the embedded documents. `to_hash['iframes']` contains the attribute
hashes.

### Meta tags

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

### Misc

```ruby
page.charset             # UTF-8
page.content_type        # content-type returned by the server when the url was requested
```

## Other representations

You can also access most of the scraped data as a hash:

```ruby
page.to_hash    # { "url"   => "https://github.com",
                    "title" => "GitHub", ... }
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

### Forced encoding

If you get a `MetaInspector::RequestError, "invalid byte sequence in UTF-8"` or similar error, you can try forcing the encoding like this:

```ruby
page = MetaInspector.new(url, :encoding => 'UTF-8')
```

### Timeout & Retries

You can specify 2 different timeouts when requesting a page:

* `connection_timeout` sets the maximum number of seconds to wait to get a connection to the page.
* `read_timeout` sets the maximum number of seconds to wait to read the page, once connected.

Both timeouts default to 20 seconds each.

These timeouts apply to fetching, not to parsing HTML. To avoid parsing large
documents, set `max_html_bytes` to a non-negative integer:

```ruby
page = MetaInspector.new(url, max_html_bytes: 2 * 1024 * 1024)
```

The default is `nil` (no limit). HTML larger than the limit raises
`MetaInspector::ParserError` before parsing, including HTML passed with the
`document` option. The limit is measured in bytes after fetching and processing
the response, so it does not limit download size or memory used for the response.
It also does not guarantee a parsing deadline: even a small document can be
slow to parse. Ruby's `Timeout.timeout` cannot reliably interrupt Nokogiri's
native parser; use a separately supervised process if a hard deadline is needed.

You can also specify the number of `retries`, which defaults to 3.

For example, this will time out after 10 seconds waiting for a connection, or after 5 seconds waiting
to read its contents, and will retry 4 times:

```ruby
page = MetaInspector.new('www.google', :connection_timeout => 10, :read_timeout => 5, :retries => 4)
```

If MetaInspector fails to fetch the page after it has exhausted its retries,
it will raise `MetaInspector::TimeoutError`, which you can rescue in your
application code.

```ruby
begin
  page = MetaInspector.new(url)
rescue MetaInspector::TimeoutError
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

You can also customize how many redirects you wish to allow:

```ruby
page = MetaInspector.new('facebook.com', :faraday_options => { redirect: { limit: 5 } })
```

And even customize what to do in between each redirect:

```ruby
callback = proc do |previous_response, next_request|
  puts "Following redirect to #{next_request.url}"
end

page = MetaInspector.new(url, faraday_options: { redirect: { callback: callback } })
```


The `faraday_options[:redirect]` hash is passed to the `FollowRedirects` middleware used by `Faraday`, so that we can use all available options.
Check them [here](https://github.com/lostisland/faraday_middleware/blob/main/lib/faraday_middleware/response/follow_redirects.rb#L44).

### Filtering request URLs

Use `url_filter:` to decide which destinations MetaInspector may request. The filter receives a Ruby `URI` and runs before the initial page request, the optional HEAD request, image size downloads, and every redirect destination. Only HTTP and HTTPS requests are supported.

For example, allow HTTPS requests to two known hosts:

```ruby
allowed_hosts = %w[example.com images.example.com]

filter = proc do |uri|
  uri.scheme == 'https' && allowed_hosts.include?(uri.hostname)
end

page = MetaInspector.new('https://example.com', url_filter: filter)
page.images.largest # Image requests and their redirects use the same filter.
```

A truthy return value permits the request. Returning `false` or `nil` raises `MetaInspector::RequestError` before contacting the rejected destination. This also applies when an image request is rejected:

```ruby
begin
  page = MetaInspector.new(url, url_filter: filter)
  page.images.largest
rescue MetaInspector::RequestError => error
  warn error.message
end
```

Exceptions raised by your filter propagate to the caller. The filter is optional: MetaInspector does not block private IP addresses by default. It applies to outgoing requests, including image downloads from HTML passed with `document:`. Reading image URLs with `images.to_a` or `images.owner_suggested` does not download them or run the filter unless invalid-image rejection is enabled.

If your application accepts arbitrary hostnames, this example rejects addresses in private, loopback, link-local and unspecified ranges, including IPv4-mapped IPv6 addresses:

```ruby
require 'ipaddr'
require 'resolv'

zero_network = IPAddr.new('0.0.0.0/8')

filter = proc do |uri|
  addresses = Resolv.getaddresses(uri.hostname)

  !addresses.empty? && addresses.all? do |address|
    ip = IPAddr.new(address)
    ip = ip.native if ip.ipv4_mapped?

    !(ip.private? || ip.loopback? || ip.link_local? ||
      ip.to_i.zero? || zero_network.include?(ip))
  end
end

page = MetaInspector.new(url, url_filter: filter)
```

DNS resolution in this example happens separately from the connection, so it cannot prevent DNS rebinding. Use network egress restrictions as well when processing untrusted URLs. The example covers the listed ranges; applications may need additional address or port restrictions.

The existing redirect `callback` keeps its two arguments and runs only on redirects. Move destination validation from that callback to `url_filter:` to cover initial URLs as well as redirects, for both pages and images.

### Headers

By default, the following headers are set:

```ruby
{
  'User-Agent'      => "MetaInspector/#{MetaInspector::VERSION} (+https://github.com/jaimeiniesta/metainspector)",
  'Accept-Encoding' => 'identity'
}
```

The `Accept-Encoding` is set to `identity` to avoid exceptions being raised on servers that return malformed compressed responses, [as explained here](https://github.com/lostisland/faraday/issues/337).

If you want to override the default headers then use the `headers` option:

```ruby
# Set the User-Agent header
page = MetaInspector.new('example.com', :headers => {'User-Agent' => 'My custom User-Agent'})
```

### Disabling SSL verification (or any other Faraday options)

Faraday can be passed options via `:faraday_options`.

This is useful in cases where we need to
customize the way we request the page, like for example disabling SSL verification, like this:

```ruby
MetaInspector.new('https://example.com')
# Faraday::SSLError: SSL_connect returned=1 errno=0 state=SSLv3 read server certificate B: certificate verify failed

MetaInspector.new('https://example.com', faraday_options: { ssl: { verify: false } })
# Now we can access the page
```

### Allow non-HTML content type

MetaInspector will by default raise an exception when trying to parse a non-HTML URL (one that has a content-type different than text/html). You can disable this behaviour with:

```ruby
page = MetaInspector.new('github.com', :allow_non_html_content => true)
```

```ruby
page = MetaInspector.new('http://example.com/image.png')
page.content_type  # "image/png"
page.description   # will raise an exception

page = MetaInspector.new('http://example.com/image.png', :allow_non_html_content => true)
page.content_type  # "image/png"
page.description   # will return a garbled string
```

### Check content type before downloading

To avoid downloading large non-HTML files, enable `head_first`:

```ruby
page = MetaInspector.new('http://example.com/page', head_first: true)
```

This sends an HTTP HEAD request before GET. If a successful HEAD response declares
a content type other than `text/html`, MetaInspector raises `MetaInspector::NonHtmlError`
without downloading the body. Content-type parameters such as `charset` are ignored.
With `allow_non_html_content: true`, the download proceeds regardless of content type.

If HEAD omits the content type or returns an unsuccessful status (including 405 or
501 for servers that do not support HEAD), MetaInspector continues with GET and its
usual content-type check. HEAD timeouts and connection errors use the same exception
handling as GET. The final page data, response headers and status come from GET.

This option is off by default because it adds a request and not every server
supports HEAD. Both requests use the configured headers, timeouts, retries and
redirect settings. Passing a `document` directly makes no HTTP requests.

### URL Normalization

By default, URLs are normalized using the Addressable gem. For example:

```ruby
# Normalization will add a default scheme and a trailing slash...
page = MetaInspector.new('github.com')
page.url # https://github.com/

# ...and it will also convert international characters
page = MetaInspector.new('http://www.詹姆斯.com')
page.url # http://www.xn--8ws00zhy3a.com/
```

While this is generally useful, it can be [tricky](https://github.com/sporkmonger/addressable/issues/182) [sometimes](https://github.com/sporkmonger/addressable/issues/160).

You can disable URL normalization by passing the `normalize_url: false` option.

### Image downloading

Image downloading is enabled by default. `page.images.with_size` and `page.images.largest` fetch images with missing HTML dimensions; `page.images.best` also does this when there is no preferred metadata image. The page controls these image URLs, which may point to other hosts.

Image requests use Faraday with the page's proxy, TLS, headers and redirect settings, and respect [`url_filter:`](#filtering-request-urls). Downloaded bytes are passed to [fastimage](https://github.com/sdsykes/fastimage) to determine dimensions. Dimensions already present in HTML are preserved without downloading the image.

Custom page headers are preserved for images on the same origin (scheme, host and port). Requests to other origins, including image redirects, send only standard image request headers such as `User-Agent` and `Accept`; they do not receive page credentials or arbitrary custom headers.

Each size lookup stops at a 256 KiB response body budget or a two-second overall timeout, including redirects. If the dimensions cannot be determined within these limits, they remain `[0, 0]`. Streamed image responses are not stored in the HTTP response cache, and failed image requests are not retried.

If you want to disable this, you can specify it like this:

```ruby
page = MetaInspector.new('http://example.com', download_images: false)
```

To limit how many images are downloaded to determine their dimensions, use `max_image_downloads`:

```ruby
page = MetaInspector.new('http://example.com', max_image_downloads: 10)
page.images.with_size
```

The default is `nil` (unlimited). The option accepts a non-negative integer or `nil`; `0` disables image downloads. `download_images: false` always disables downloads, regardless of the limit.

By default, the limit counts image size lookup attempts in HTML order, after excluding unparseable URLs and duplicates. Images with both HTML dimensions already present do not consume the limit, and those dimensions are preserved even after the limit is reached. Failed lookups count toward the limit. Images with incomplete dimensions that are not downloaded remain in `images.with_size` with dimensions `[0, 0]`, matching the behavior when downloads are disabled.

By default, the limit leaves `images.to_a` unchanged, but can affect `images.largest` and the largest-image fallback in `images.best`, since images with unknown dimensions cannot be ranked by size. Size lookup results are cached per document, so repeated calls reuse the same results. This limits size lookup attempts, not elapsed time or HTTP requests made while following image redirects.

To discard images that cannot be read by FastImage, opt in to validation:

```ruby
page = MetaInspector.new('http://example.com',
  download_image_options: { reject_invalid_images: true })
page.images.to_a            # excludes images that failed validation
page.images.owner_suggested # first suggested image that has not failed validation
page.images.best            # falls back to another suggested or page image
```

Validation downloads images even when HTML dimensions are present. It applies to
the image collection, `with_size`, and suggested images; it does not validate the
favicon. A failed HTTP request, an unsuccessful response, or a response whose
dimensions FastImage cannot determine is invalid. This is a bounded image-header
check, not a guarantee that the entire image can be downloaded or decoded.

For validity information without filtering the collection, enable
`fetch_all_image_meta` and call `with_metadata`:

```ruby
page = MetaInspector.new('http://example.com', fetch_all_image_meta: true)
page.images.with_metadata # [{ url: 'http://example.com/image.png', valid: true }, ...]
```

Metadata follows the original image collection order and includes invalid entries,
even when rejection is also enabled. Duplicate `src` values are removed before URLs
are resolved. `valid` is `true` or `false`
for a lookup that was attempted, and `nil` when no lookup was made (including an
unresolvable URL). Without `fetch_all_image_meta`, `with_metadata` does not initiate
validation and returns `nil` validity values.

Both options respect `download_images: false` and `max_image_downloads`. Images
that cannot be checked because downloads are disabled or the budget is exhausted
are retained, with unknown validity. Suggested images and collection images share
the budget in the order they are first queried; repeated URLs reuse their results.
Consequently the order of API calls can affect which images are checked when a
limit is set. URL filter errors still propagate to the caller.

### Caching responses

MetaInspector can be configured to use [Faraday::HttpCache](https://github.com/plataformatec/faraday-http-cache) to cache page responses. For that you should pass the `faraday_http_cache` option inside `faraday_options`, with at least the `:store` key, for example:

```ruby
cache = ActiveSupport::Cache.lookup_store(:file_store, '/tmp/cache')
page = MetaInspector.new('http://example.com', faraday_options: { faraday_http_cache: { store: cache } })
```

The top-level `faraday_http_cache` option still works, but it is deprecated and prints a warning, once per process. Passing it in both places raises an `ArgumentError`.

## Exception Handling

Web page scraping is tricky, you can expect to find different exceptions during the request of the page or the parsing of its contents. MetaInspector will encapsulate these exceptions on these main errors:

* `MetaInspector::TimeoutError`. When fetching a web page has taken too long.
* `MetaInspector::RequestError`. When there has been an error on the request phase. Examples: page not found, SSL failure, invalid URI.
* `MetaInspector::ParserError`. When there has been an error parsing the contents of the page.
* `MetaInspector::NonHtmlError`. When the contents of the page was not HTML. See also the `allow_non_html_content` option

## Examples

You can find some sample scripts on the `examples` folder, including a basic scraping and a spider that will follow external links using a queue. What follows is an example of use from irb:

```ruby
$ irb
>> require 'metainspector'
=> true

>> page = MetaInspector.new('http://github.com')
=> #<MetaInspector:0x11330c0 @url="http://github.com">

>> page.title
=> "GitHub"

>> page.meta['description']
=> "Join the most widely adopted, AI-powered developer platform where millions of developers, businesses, and the largest open source community build software that advances humanity."
```

## Contributing guidelines

You're more than welcome to fork this project and send pull requests. Just remember to:

* Create a topic branch for your changes.
* Add specs.
* Keep your fake responses as small as possible. For each change in `spec/fixtures`, a comment should be included explaining why it's needed.
* Update `README.md` if needed (for example, when you're adding or changing a feature).

Thanks to all the contributors:

[https://github.com/jaimeiniesta/metainspector/graphs/contributors](https://github.com/jaimeiniesta/metainspector/graphs/contributors)

You can also come to chat with us on our [Gitter room](https://gitter.im/jaimeiniesta/metainspector) and [Google group](https://groups.google.com/forum/#!forum/metainspector).

## Related projects

* [go-metainspector](https://github.com/fern4lvarez/go-metainspector), a port of MetaInspector for Go.
* [Node-MetaInspector](https://github.com/gabceb/node-metainspector), a port of MetaInspector for Node.
* [MetaInvestigator](https://github.com/nekova/metainvestigator), a port of MetaInspector for Elixir.
* [Funkspector](https://github.com/jaimeiniesta/funkspector), another port of MetaInspector for Elixir.

## License
MetaInspector is released under the [MIT license](MIT-LICENSE).
