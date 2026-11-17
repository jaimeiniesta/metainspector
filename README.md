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

## Options reference

Pass these options as the second argument to `MetaInspector.new(url, options)`.

| Option | Default | Description |
| --- | --- | --- |
| `connection_timeout` | `20` | Maximum seconds to wait for a connection. |
| `read_timeout` | `20` | Maximum seconds to wait for a read once connected. |
| `retries` | `3` | Maximum additional attempts after a timeout. See [Timeout & Retries](#timeout--retries). |
| `allow_redirections` | `true` | Follow redirects, up to 10 by default; customize with `faraday_options[:redirect]`. |
| `head_first` | `false` | Check content type with HEAD before downloading with GET. |
| `document` | `nil` | HTML string to parse instead of fetching the page. |
| `headers` | User-Agent and Accept-Encoding | Request headers; a custom hash replaces the [default headers](#headers). |
| `encoding` | `nil` | Force the fetched body's encoding instead of relying on automatic detection. |
| `normalize_url` | `true` | Normalize URLs using Addressable. |
| `allow_non_html_content` | `false` | Allow non-HTML responses to be passed to the HTML parser. |
| `download_images` | `true` | Allow image downloads for dimensions, metadata and validation. |
| `max_image_downloads` | `nil` (unlimited) | Limit image lookup attempts; `0` disables image downloads. |
| `download_image_options` | `nil` | Set `reject_invalid_images: true` in a hash to discard images that fail validation. |
| `fetch_all_image_meta` | `nil` (disabled) | Enable validity lookups through `images.with_metadata`. |
| `inline_image_data` | `nil` (disabled) | Return full data URLs and allow inline images in `best` and `largest`. |
| `max_html_bytes` | `nil` (unlimited) | Byte limit for each response body, decompression stage and processed HTML; exceeding it raises `ParserError`. See [Timeout & Retries](#timeout--retries). |
| `url_filter` | `nil` | Callable receiving a URI before each request; `false` or `nil` rejects the destination. |
| `faraday_options` | `nil` | Faraday configuration, including `redirect` and `faraday_http_cache` settings. |
| `faraday_http_cache` (deprecated) | `nil` | Legacy cache configuration; use `faraday_options[:faraday_http_cache]` instead. |

## Accessing response

You can check the status and headers from the response like this:

```ruby
page.response.status  # 200
page.response.headers # { "server"=>"nginx", "content-type"=>"text/html; charset=utf-8",
                      #   "cache-control"=>"must-revalidate, private, max-age=0", ... }
```

When the HTML is passed with the `document` option, no request is made, so
`page.response` and `page.content_type` return `nil`, and so do the `response`
and `content_type` keys of `to_hash`.

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
page.feeds               # RSS, Atom or JSON feed links as an array of hashes: { href: "...", title: "...", type: "..." }
```

`feeds` returns `<link rel="alternate">` elements whose `type` is
`application/rss+xml`, `application/atom+xml`, `application/feed+json` (JSON Feed
1.1) or `application/json` (JSON Feed 1.0). The type is matched case-insensitively
and ignoring parameters such as `; charset=utf-8`; `type` in the result is the
attribute as written.

`page.feed` is a deprecated compatibility method that returns the first RSS or
Atom feed's absolute URL, or `nil` if none is found. It skips JSON feeds. Each
call emits a deprecation warning. Use `page.feeds` instead; `page.feed` is
scheduled for removal in **6.0**.

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
page.images              # enumerable collection of image URLs found on the page
page.images.with_size    # a sorted array (by descending area) of [image_url, width, height]
page.images.with_details # image hashes with dimensions, type and file size (downloads images)
page.images.with_metadata # image hashes with URL and validity (enable lookups with fetch_all_image_meta: true)
page.images.largest      # largest image, excluding aspect ratios of 10:1 or wider and 1:10 or taller
page.images.owner_suggested # first image from og:image, twitter:image, or parsely-image-url
page.images.best         # Most relevant image from og:image, twitter:image, or parsely-image-url; falls back to page.images.largest
page.images.favicon      # absolute URL to the favicon
```

`page.favicon` is a deprecated shortcut for `page.images.favicon`, returning the
same URL or `nil`. Each call emits a deprecation warning. Use
`page.images.favicon` instead; `page.favicon` is scheduled for removal in **6.0**.

The collection includes `img[src]`, `img[srcset]`, and `source[srcset]` inside
`picture`, resolved to absolute URLs and deduplicated. Elements appear in document
order; for each `img`, `src` comes before its `srcset` candidates, which retain
their listed order. All candidates are included regardless of media conditions or
device density. Responsive candidates use their downloaded dimensions for ranking;
the `img` element's width and height apply only to its `src` fallback. By default,
non-HTTP responsive URLs remain in the collection but cannot be downloaded for sizing.

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
page.content_type        # content-type returned by the server when the url was requested, or nil with the document option
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
page.parsed  # Nokogiri::HTML5::Document that you can use to get any element from the page
```

The DOM follows HTML5 parsing rules, including keeping paragraphs inside headings
produced by CMS editors. Malformed markup may produce a different tree than the
previous HTML4 parser. HTML5 also normalizes literal CR and CRLF line endings to
LF, including in attribute values; `to_s` still returns the original document.
For legacy charsets that Ruby cannot convert to UTF-8 (such as UTF-7),
MetaInspector retains the HTML4 document and its parsing behavior.

## Options

### Forced encoding

Invalid byte sequences in the page's encoding are replaced with U+FFFD before
parsing, as browsers do, so one bad byte doesn't stop the rest of the page from
being read. If a page declares the wrong charset, you can force the right one:

```ruby
page = MetaInspector.new(url, :encoding => 'Windows-1252')
```

For HTML passed with `document:`, the original string is still available through `page.to_s`.

Legacy HTML charsets use browser-compatible supersets: GB2312 uses GBK,
Shift_JIS uses Windows-31J, EUC-KR uses CP949, Big5 uses Big5-HKSCS, and
ISO-8859-1 uses Windows-1252. This applies to HTTP charset declarations, HTML
meta declarations and the encoding of supplied strings, preserving characters
outside the strict legacy charset and the rest of the document. Declared meta
charsets and raw response bytes are preserved. Strings tagged with one of these
legacy encodings are converted to UTF-8 before cleanup; `page.to_s` returns the
converted text for downloaded pages.

Fetched bodies with non-ASCII-compatible encodings, such as UTF-16, UTF-32 and
ISO-2022-JP, are converted to UTF-8 before NUL characters are removed and the HTML
is parsed. `page.to_s` returns that UTF-8 text; the conversion preserves the raw
`page.response.body`. Invalid bytes are replaced with U+FFFD; conversions Ruby
doesn't support, such as UTF-7, raise `MetaInspector::RequestError` with the
original encoding error as the cause.

### Timeout & Retries

You can specify 2 different timeouts when requesting a page:

* `connection_timeout` sets the maximum number of seconds to wait to get a connection to the page.
* `read_timeout` sets the maximum number of seconds to wait for a read, once connected.

Both timeouts default to 20 seconds each.

These timeouts apply to fetching, not to parsing HTML. To avoid parsing large
documents, set `max_html_bytes` to a non-negative integer:

```ruby
page = MetaInspector.new(url, max_html_bytes: 2 * 1024 * 1024)
```

The default in 5.x is `nil` (no limit). Set a finite limit when fetching URLs you
do not control. Exceeding it raises `MetaInspector::ParserError` during
initialization. The limit applies separately to the bytes received for each
response (including redirect bodies), each stage of gzip/deflate decompression,
and the HTML after charset conversion and processing, before parsing. Downloads
stop as soon as a received chunk exceeds the limit; decompression stops as soon
as an output chunk exceeds it, without expanding the entire body. Cached
responses are checked too. With a finite limit, only gzip and deflate compression
are supported; other content encodings raise `MetaInspector::RequestError`.
HTML passed with `document:` is checked before parsing as well.

This bounds response buffers, not total process memory: charset conversion and
DOM construction still need additional memory. It also does not guarantee a
parsing deadline: even a small document can be
slow to parse. Ruby's `Timeout.timeout` cannot reliably interrupt Nokogiri's
native parser; use a separately supervised process if a hard deadline is needed.

Nokogiri also enforces limits on nesting depth and the size of individual text
nodes, attribute values and comments. If one of these limits truncates the HTML,
MetaInspector raises `MetaInspector::ParserError` during initialization, with the
parser's diagnostic in the message. These limits apply even when `max_html_bytes`
is `nil`. MetaInspector retains an HTML4 pass for the size limits and encoding
detection before building the HTML5 DOM. The nesting limit is HTML5's, 400
levels; for legacy charsets that Ruby cannot transcode, where the HTML4 tree is
the DOM, it is HTML4's, 256 levels. Ordinary HTML errors and recoverable
encoding errors are still tolerated.

You can also specify the maximum number of additional attempts with `retries`,
which defaults to 3. Connection timeouts and read timeouts are retried. Other
connection failures, such as a refused connection or a DNS failure, are not.

Each attempt also has a deadline of `connection_timeout + read_timeout + 1`
seconds, which covers its redirects. It stops servers that keep sending data
slowly enough that the read timeout never fires. With the defaults, this is 41
seconds. An attempt that reaches the deadline is not retried, so such a server
holds the fetch for 41 seconds, not 41 for each retry. With `head_first: true`,
the HEAD and GET requests each get their own attempts.

For example, this allows up to 10 seconds to connect and 5 seconds per read, with
up to 4 additional attempts after a timeout, each within a 16-second deadline:

```ruby
page = MetaInspector.new('https://example.com', connection_timeout: 10, read_timeout: 5, retries: 4)
```

If the last attempt times out, or any attempt reaches the deadline, MetaInspector
raises `MetaInspector::TimeoutError`; other connection failures raise
`MetaInspector::RequestError`. Rescue both if your application handles them the
same way:

```ruby
begin
  page = MetaInspector.new(url)
rescue MetaInspector::TimeoutError, MetaInspector::RequestError
  enqueue_for_future_fetch_attempt(url)
  render_simple(url)
else
  render_rich(page)
end
```

### Redirections

By default, MetaInspector will follow redirects (up to a limit of 10).

Custom headers are retained only on the initial page origin (scheme, host and port).
For redirects to a different origin, including subdomains, different ports and
HTTPS-to-HTTP redirects, only `User-Agent`, `Accept`, `Accept-Language` and
`Accept-Encoding` are forwarded. This applies to GET and HEAD requests and to
headers supplied through either `headers:` or `faraday_options[:headers]`.
Credentials from the initial request are also withheld from images on a redirected
page at a different origin. Image requests retain their generated `Range` header.

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


The `faraday_options[:redirect]` hash is passed to the `faraday-follow_redirects`
middleware. See its [available options](https://github.com/tisba/faraday-follow-redirects#usage).
The origin header policy also applies after your redirect callback runs and when
`clear_authorization_header: false` is set.

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

`Accept-Encoding: identity` requests uncompressed responses to reduce problems with
malformed compressed data. Servers may still send compressed responses. gzip and
deflate are decoded, and malformed gzip or deflate data raises
`MetaInspector::RequestError`. Other encodings, such as `br` or `zstd`, also raise
`MetaInspector::RequestError` instead of being parsed as HTML. To decode `br`, add
the [`brotli`](https://rubygems.org/gems/brotli) gem to your Gemfile; this doesn't
apply with `max_html_bytes`, which only decodes gzip and deflate.

If you want to override the default headers then use the `headers` option:

```ruby
# Set the User-Agent header
page = MetaInspector.new('example.com', :headers => {'User-Agent' => 'My custom User-Agent'})
```

The `headers` option replaces all default headers. To keep requesting uncompressed
responses with a custom User-Agent, also pass `'Accept-Encoding' => 'identity'`.
Otherwise, the compression middleware requests compressed responses automatically.

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

MetaInspector fetches and parses the document during initialization. By default,
`MetaInspector.new` raises `MetaInspector::NonHtmlError` if the response declares a
content type other than `text/html`. You can disable this behaviour with:

```ruby
page = MetaInspector.new('github.com', :allow_non_html_content => true)
```

```ruby
begin
  page = MetaInspector.new('http://example.com/image.png')
rescue MetaInspector::NonHtmlError => error
  warn error.message # The url provided contains image/png content instead of text/html content
end

page = MetaInspector.new('http://example.com/image.png', :allow_non_html_content => true)
page.content_type  # "image/png"
page.description   # usually nil; non-HTML data is still passed to the HTML parser
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
# Normalization adds the default http scheme and a trailing slash.
# Supplying HTML avoids a request, so redirects cannot change the URL.
page = MetaInspector.new('example.com', document: '<html></html>')
page.url # http://example.com/

# ...and it will also convert international characters
page = MetaInspector.new('http://www.詹姆斯.com')
page.url # http://www.xn--8ws00zhy3a.com/
```

When a page is fetched with redirects enabled, `page.url` is updated to the final
URL. For example, an HTTPS URL after requesting `github.com` reflects GitHub's
redirect from HTTP, rather than a default HTTPS scheme.

Normalization leaves the query string as written, except for characters that
can't be sent in a URL, such as spaces, non-ASCII characters, `|`, `{`, `}` or a
`%` that doesn't start an escape. Reserved characters such as `;` and `[]`, and
existing escapes such as `%2F`, are kept, because changing them can change the
page the server returns. The same applies to the URLs in `links` and `head_links`:

```ruby
page = MetaInspector.new('http://example.com/?a[]=1;b=café')
page.url # http://example.com/?a[]=1;b=caf%C3%A9
```

While this is generally useful, it can be [tricky](https://github.com/sporkmonger/addressable/issues/182) [sometimes](https://github.com/sporkmonger/addressable/issues/160).

You can disable URL normalization by passing the `normalize_url: false` option.

### Inline images

By default, image results replace each `data:` URL with its header before the comma,
for example `data:image/png;base64`. This applies to the image collection, image
metadata and size results, suggested images, favicon, and `to_hash`; raw `meta_tags`
are unchanged. Different inline images can have the same displayed header. `best`
and `largest` skip inline images when these placeholders are used.

Pass `inline_image_data: true` to return full data URLs and allow them to compete
for `best` and `largest`. Base64 and percent-encoded data images are decoded locally
for dimensions and metadata, without a network request or using the download budget.
`download_images: false` disables these lookups too.

### Image downloading

Image downloading is enabled by default. `page.images.with_size` and `page.images.largest` fetch images with missing HTML dimensions; `page.images.best` also does this when there is no preferred metadata image. The page controls these image URLs, which may point to other hosts.

Image requests use Faraday with the page's proxy, TLS, headers and redirect settings, and respect [`url_filter:`](#filtering-request-urls). Downloaded bytes are passed to [fastimage](https://github.com/sdsykes/fastimage) to determine dimensions. Dimensions already present in HTML are preserved without downloading the image.

To opt in to image type and file size, use:

```ruby
page.images.with_details
# => [{ url: "https://example.com/photo.png", width: 640, height: 480,
#       type: :png, file_size: 12345 }]
```

The array is sorted by descending image area and contains one entry per valid, unique image URL. `type` is a FastImage symbol, or `nil` if it cannot be identified. `file_size` is the total in bytes: the `Content-Length` of an unencoded 200 response, the total in a 206 `Content-Range`, or the byte count of a fully downloaded unencoded 200 response without a `Content-Length`. It is `nil` when the total is unavailable; a partial download's byte count is never used as the total. Servers can report inaccurate lengths. Failed requests return `nil` for both fields; URL policy errors still propagate. Each HTML dimension is preserved when present; a missing dimension is obtained from the image or becomes zero if it cannot be determined.

Metadata lookup attempts downloads even when HTML dimensions are present, subject to `download_images`, `max_image_downloads`, and the same request restrictions and byte/time limits described below. The limit counts attempts in HTML order, including failures. Results are cached separately from `with_size`; calling both methods can download an image twice and each method applies the limit independently. When `reject_invalid_images` or `fetch_all_image_meta` is enabled, `with_details` reuses the validation lookups instead, as described below.

Custom page headers are preserved for images on the same origin (scheme, host and port). Requests to other origins, including image redirects, send only standard image request headers such as `User-Agent` and `Accept`; they do not receive page credentials or arbitrary custom headers. They also send a `Referer` containing only the page origin, except when an HTTPS page requests an HTTP image. The page path, query, fragment and credentials are never included in this cross-origin `Referer`.

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
the image collection, `with_size`, `with_details`, and suggested images; it does
not validate the favicon. A failed HTTP request, an unsuccessful response, or a
response whose dimensions FastImage cannot determine is invalid. An image URL that
uses an unsupported scheme is invalid without a request. Valid `data:` images are decoded locally. URLs
with non-ASCII characters are normalized before the request; results keep the
original URL. This is a bounded image-header check, not a guarantee that the
entire image can be downloaded or decoded.

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
that cannot be checked because downloads are disabled or the HTTP budget is exhausted
are retained, with unknown validity. Local data images and URLs found invalid without
a request do not count toward the limit. Suggested images and collection images share
the budget in the order they are first queried; repeated URLs reuse their results.
Consequently the order of API calls can affect which images are checked when a
limit is set. URL filter errors still propagate to the caller.

With either option, `with_details` takes type and file size from these validation
lookups, so each image is downloaded at most once and shares the same budget.
Unsupported image URL schemes get `nil` metadata instead of raising; redirects to unsupported schemes still raise. With
`reject_invalid_images`, `with_details` omits images that failed validation, like
`with_size`; images that were not checked are kept with `nil` type and file size.

### Caching responses

MetaInspector can be configured to use [Faraday::HttpCache](https://github.com/sourcelevel/faraday-http-cache) to cache page responses. For that you should pass the `faraday_http_cache` option inside `faraday_options`, with at least the `:store` key, for example:

```ruby
cache = ActiveSupport::Cache.lookup_store(:file_store, '/tmp/cache')
page = MetaInspector.new('http://example.com', faraday_options: { faraday_http_cache: { store: cache } })
```

The top-level `faraday_http_cache` option still works, but it is deprecated and prints a warning, once per process. Passing it in both places raises an `ArgumentError`.

## Exception Handling

Web page scraping is tricky, you can expect to find different exceptions during the request of the page or the parsing of its contents. MetaInspector will encapsulate these exceptions on these main errors:

* `MetaInspector::TimeoutError`. When connecting or reading times out and no retries are left, or an attempt reaches its deadline. See [Timeout & Retries](#timeout--retries).
* `MetaInspector::RequestError`. When there has been an error on the request phase. Examples: DNS failure, refused connection, SSL failure, invalid URI, malformed compressed response.
* `MetaInspector::ParserError`. When there has been an error parsing the contents of the page.
* `MetaInspector::NonHtmlError`. When the contents of the page was not HTML. See also the `allow_non_html_content` option

HTTP error statuses such as 403, 404 and 500 do not raise `MetaInspector::RequestError`. Their response bodies are processed like any other page, and you can check the status through `page.response.status`:

```ruby
page = MetaInspector.new(url) # a URL that returns an HTML error page
page.response.status         # => 404
page.title                   # => the title of the error page
```

## Examples

Runnable sample scripts live in `examples/`. From the repository root, pass the URL as an argument:

```sh
bundle exec ruby examples/basic_scraping.rb https://example.com
```

You can also run them from inside `examples/`, for example `bundle exec ruby basic_scraping.rb https://example.com`. If no URL is supplied, the scripts prompt for one, except `faraday_redirect_options.rb`, which defaults to `https://example.com`.

* `basic_scraping.rb`: prints the page title, metadata and links, plus the page data as JSON.
* `spider.rb`: follows internal links using a queue and lists the pages visited.
* `link_checker.rb`: checks linked pages and reports broken links with their origin.
* `faraday_redirect_options.rb`: restricts requests to allowed HTTPS hosts with `url_filter:` and logs redirects with a callback.
* `responsive_images.rb`: lists `img[src]`, `img[srcset]` and `picture source[srcset]` candidates, plus the best image.
* `image_details.rb <url> [max_downloads]`: prints dimensions, type and file size, largest first; image downloads default to a limit of 10.
* `image_validation.rb <url> [max_downloads]`: reports image validity, filters invalid candidates and prints the best image; image downloads default to a limit of 10, with remaining images reported as not checked.
* `iframes.rb`: lists iframe attributes and resolved source URLs without downloading embedded documents.
* `html_size_limit.rb <url> [max_bytes]`: skips HTML over the byte limit (default: 2 MiB). The limit applies after download and does not bound parse time.

What follows is an example of use from irb. The `; nil` suppresses the document's
lengthy inspection output:

```ruby
$ irb
>> require 'metainspector'
=> true

>> page = MetaInspector.new('http://github.com'); nil
=> nil

>> page.class
=> MetaInspector::Document

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
