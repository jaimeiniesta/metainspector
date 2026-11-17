# MetaInspector Changelog

## Unreleased

* **Breaking:** `max_image_downloads` defaults to `20` instead of `nil` (unlimited), so a page with many images no longer decides how many requests `images.with_size`, `images.largest` and `images.best` make. Images past the limit that lack HTML dimensions get `[0, 0]` and can't win `largest`. Pass `max_image_downloads: nil` to keep downloading every image (#600).
* **Breaking:** raise `ArgumentError` for unknown options, naming them, instead of ignoring them. A misspelled option, or one with a String key as read from JSON or YAML, did nothing: `MetaInspector.new(url, 'document' => html)` fetched the page instead of parsing `html`. Option keys must be Symbols (#604).
* **Breaking:** `title` returns `nil` instead of `""` when the head has no `<title>` or it is blank, like `description`, `author` and the other readers, so `page.title || fallback` reaches the fallback. `title`, `description` and `best_description` trim surrounding whitespace, and `description` returns `nil` for a blank meta description; whitespace inside the text is kept as written. `to_hash['title']` and `to_hash['description']` change the same way (#604).
* **Breaking:** remove `page.feed` and `page.favicon`, which warn as deprecated since 5.21.0. Use `page.feeds` and `page.images.favicon` (#604).
* **Breaking:** remove the top-level `faraday_http_cache` option, deprecated in 5.20.0. Pass it inside `faraday_options`: `faraday_options: { faraday_http_cache: { store: cache } }`. The top-level option now raises `ArgumentError` (#604).
* **Breaking:** `images.with_size`, `images.largest` and `images.best` download one candidate per `<img>` or `<picture>` instead of every `srcset` candidate, which roughly tripled image downloads since 5.21.0. Each image is ranked by its largest candidate: the largest width descriptor if any, otherwise the highest density, with `src` as `1x`. A `src` with `width` and `height` in the HTML is still ranked without a download. **`with_size` changes**: it no longer lists the smaller candidates of each image. `to_a` and `with_details` still list every candidate (#600).

## [Changes in 5.22.0](https://github.com/jaimeiniesta/metainspector/compare/v5.21.2...v5.22.0)

* `feeds` returns [JSON Feed 1.1](https://www.jsonfeed.org/version/1.1/) links (`application/feed+json`), and matches feed types case-insensitively and ignoring parameters, so `Application/Atom+XML` and `application/rss+xml; charset=utf-8` are found too. `type` keeps the attribute as written. The deprecated `feed` method still returns only RSS and Atom feeds, now also with parameters (#599).
* Raise `MetaInspector::TimeoutError` instead of `MetaInspector::RequestError` when connecting times out, and retry connection timeouts like read timeouts. **The error class changes**: if you rescue only `MetaInspector::RequestError`, rescue `MetaInspector::TimeoutError` too. Refused connections, DNS failures and other connection errors still raise `RequestError` and are not retried. The `connection_timeout + read_timeout + 1` deadline now applies to each attempt instead of the whole fetch, so `retries` gets all its attempts: before, `retries: 3` stopped after two or three. An attempt that reaches the deadline, such as one to a server that streams forever, is not retried, so it still raises `TimeoutError` after 41 seconds with the defaults. A page whose connection or read times out on every attempt now takes up to 4 × 40 seconds to fail, instead of 41 (#598).
* Raise `MetaInspector::RequestError` when a response is still compressed with an encoding MetaInspector doesn't decode, such as `br` or `zstd`, instead of parsing the compressed bytes as HTML and returning an empty page. Servers can send these even when asked for `Accept-Encoding: identity`. Adding the `brotli` gem enables `br` (#597).
* Replace invalid byte sequences in fetched pages with U+FFFD, as browsers do, instead of raising `MetaInspector::RequestError` when the charset comes from the `Content-Type` header. Before, they were only replaced with the `encoding:` option (#596).
* Resolve charset labels with the [Encoding Standard](https://encoding.spec.whatwg.org/#names-and-labels) table, as browsers do. Labels such as `ks_c_5601-1987`, `x-sjis`, `x-gbk` or `unicode-1-1-utf-8` no longer leave the page empty or garbled. `us-ascii` and `ascii` decode as Windows-1252 instead of raising `MetaInspector::RequestError`, and `iso-8859-9` and `iso-8859-11` as Windows-1254 and Windows-874. A UTF-16 label in a meta tag is read as UTF-8. A meta label that neither the table nor Ruby knows is ignored instead of cutting the document at the meta tag (#595).
* Return links inside inline `<svg>` and `<math>` again in `links`, as in 5.21.0. With the HTML5 parser those `<a>` elements are in another namespace, and the `//a/@href` lookup skipped them (#593).
* Return a page again for PDFs, binary files and deeply nested feeds with `allow_non_html_content: true`, instead of raising `MetaInspector::ParserError`. When the response is not `text/html`, parser resource limits no longer raise; if the HTML5 parser gives up, `parsed` falls back to the depth-capped HTML4 tree, as in 5.21.0. HTML responses and `max_html_bytes` are still enforced (#592).
* Fix `to_hash` raising `NoMethodError` on compressed responses. Header values that are not Strings, such as the Integer `Content-Length` set by faraday-gzip after decompressing, are kept as they are, and header names are downcased so `content-length` can be looked up as before (#591).
* Decode fetched UTF-16 and UTF-32 pages with a byte-order mark before removing NUL characters, even when the HTTP header has no charset. Preserve the raw response body and prefer the mark over conflicting meta declarations (#601).
* Preserve titles, head links and page content after tracking snippets in `<noscript>`, including unclosed or self-closing iframes. Parse each fallback separately so its links, images, stylesheets and iframes remain available (#602).
* Use the first meta charset declaration for binary HTML bodies, so a later conflicting declaration no longer garbles text or truncates the page. Preserve HTTP and string encodings, and prefer a byte-order mark over meta declarations (#575).
* Parse the DOM with HTML5 rules so paragraphs inside `h1`–`h6` retain their text, including the `best_title` heading fallback (#566). `parsed` now returns `Nokogiri::HTML5::Document`; malformed markup can produce a different tree, and literal CR/CRLF line endings in text and attributes normalize to LF. Preserve HTML4 encoding detection and text-size limits before HTML5 parsing, and wrap HTML5 depth-limit failures in `MetaInspector::ParserError`. Retain HTML4 parsing for legacy charsets that Ruby cannot transcode to UTF-8.
* Parse responses declared as UTF-16, UTF-32 or ISO-2022-JP by converting non-ASCII-compatible bodies to UTF-8 before removing NUL characters. Preserve the raw response body during conversion, replace invalid bytes with U+FFFD (#596) and wrap unsupported encoding conversions, such as UTF-7, in `MetaInspector::RequestError` (#568).
* Raise `MetaInspector::ParserError` during initialization when Nokogiri truncates HTML at its nesting or content resource limits, instead of silently returning incomplete links, headings and other metadata. Other recoverable HTML and encoding errors remain tolerated (#565). The nesting limit is the HTML5 parser's (400 levels), so pages that libxml2 truncated at 256 levels in 5.21.0 are now parsed in full. These include pages that only nest that deep in libxml2's HTML4 tree, such as unclosed `<div>`s inside `<section>`s; legacy charsets that Ruby cannot transcode keep the 256 limit. The 10 MB limit on text, attribute values and comments still applies past libxml2's nesting limit (#612).
* Convert response header values in `to_hash` to UTF-8, replacing invalid bytes, so non-ASCII headers no longer prevent JSON serialization. The original `response.headers` values are preserved (#563).
* Replace invalid byte sequences before parsing HTML passed with `document:`, so extracted text and `to_hash` no longer raise encoding errors. The original string returned by `to_s` is preserved (#569).
* Wrap malformed gzip/deflate responses and invalid `mailto:` page URLs or redirect destinations in `MetaInspector::RequestError`. Invalid `mailto:` image URLs return unknown dimensions instead of raising (#567).
* Return only the first `<title>` in the head for `title` and `to_hash['title']`, instead of concatenating all titles (#564).
* Fix `charset` returning `nil` for lowercase or mixed-case `http-equiv="content-type"` declarations. Read the `charset` parameter by name regardless of parameter order, spacing or case, and remove surrounding quotes (#562).
* Fix swapped `connection_timeout` and `read_timeout` options for GET and HEAD requests (#561). The connection timeout now limits opening the connection, and the read timeout limits waiting for the response.
* Fix garbled titles, descriptions and other text on compressed pages whose charset is declared only in the `Content-Type` header, including when custom headers enable compression (#572). Apply the charset after decompressing the response body.
* `untracked_url` and `untrack!` remove only the `utm_*` tracking parameters and keep the rest of the query string as written, instead of sorting keys, dropping repeated keys and re-encoding values (#557). **The returned URL changes** for any query with more than one parameter, or with `+` in a value: `?b=2&a=1` used to come back as `?a=1&b=2` and `?q=a+b` as `?q=a%20b`. If you store `untracked_url` values to spot duplicate pages, new results may not match the ones you saved before, so normalize both sides yourself or re-generate the stored values.
* Request page and image URLs with the query string as given, instead of sorting keys, keeping only the last value of a repeated key (`?tag=x&tag=y` was requested as `?tag=y`) and re-escaping values. URLs with non-UTF-8 escapes such as `?q=caf%E9` no longer raise `ArgumentError` (#594). **`url` changes too**: it reports the query that was requested, so, as with `untracked_url` above, stored values for queries with more than one parameter may not match new ones. With `normalize_url: true`, the default, normalization now escapes only what can't be sent (spaces, non-ASCII characters, `|`, `{`, `}`, a `%` that doesn't start an escape) and keeps reserved characters such as `;` and `[]` and existing escapes such as `%2F` or `%3D` as written, instead of escaping or decoding them (#613). **`links` and `head_links` change too** for queries with those characters, so stored link URLs may not match new ones either. Pass `normalize_url: false` to send the page URL unchanged.
* Fix `to_hash`, `content_type` and `response` raising `NoMethodError` when the HTML is passed with the `document` option. No request is made in that case, so `content_type` and `response` return `nil`, and `to_hash` includes `'content_type' => nil` and `'response' => nil` (#559).
* Fix `links`, `images`, `iframe_sources`, `head_links` and `feeds` taking quadratic time on pages with thousands of links, images, iframes or `<link>` elements. The whole document was searched for a `<base>` element once per element found; now it's searched once per page. Getting the links of a 700 KB page with 32,000 of them goes from 21 seconds to about 1, and results don't change (#573).

## [Changes in 5.21.2](https://github.com/jaimeiniesta/metainspector/compare/v5.21.1...v5.21.2)

* Security: apply `max_html_bytes` while downloading page and redirect responses and during gzip/deflate decompression, before charset conversion and parsing. Oversized responses raise `MetaInspector::ParserError`; cached responses are checked as well. The 5.x default remains `nil` (unlimited); set a finite limit for untrusted URLs. Other content encodings are rejected with a finite limit ([GHSA-36j3-rh89-4gm2](https://github.com/jaimeiniesta/metainspector/security/advisories/GHSA-36j3-rh89-4gm2)).

## [Changes in 5.21.1](https://github.com/jaimeiniesta/metainspector/compare/v5.21.0...v5.21.1)

* Security: forward only `User-Agent`, `Accept`, `Accept-Language` and `Accept-Encoding` when page redirects change the origin (scheme, host or port), preventing custom credentials from reaching another origin. Apply the policy to GET and HEAD, including headers supplied through `faraday_options`, and keep the initial credentials out of image requests on the redirected origin. Custom headers remain available within the initial origin ([GHSA-mcmp-j8cq-h65f](https://github.com/jaimeiniesta/metainspector/security/advisories/GHSA-mcmp-j8cq-h65f)).

## [Changes in 5.21.0](https://github.com/jaimeiniesta/metainspector/compare/v5.20.0...v5.21.0)

* Restore working `page.feed` and `page.favicon` compatibility methods with deprecation warnings and removal scheduled for 6.0. `feed` returns the first RSS/Atom URL (or `nil`), and `favicon` returns `images.favicon`. Migrate to `page.feeds` and `page.images.favicon` (#547).
* Match favicon `rel` tokens case-insensitively across ASCII whitespace, including `alternate icon`, while rejecting unrelated substrings and retaining legacy `shortcut` links (#548).
* Match feed, stylesheet and canonical `rel` keywords case-insensitively within ASCII whitespace-separated token lists (#549).
* Skip whitespace-only metadata in `best_description` so later metadata and paragraph fallbacks are considered (#550).
* Example scripts run from any directory and are verified in the test suite. New examples for responsive images, image details, image validation, iframes and `max_html_bytes`; the unused redirect test server is removed (#538).
* Decode `data:` images locally and treat other unsupported image schemes as unknown without consuming the download budget; URL-filter rejections and redirects to unsupported schemes still raise (#544).
* Image results now omit `data:` URL payloads by default, including in `to_a` and `to_hash`. Set `inline_image_data: true` to retain full URLs; otherwise `best` and `largest` skip inline images (#545).
* Fix downloading and validating image URLs containing Unicode characters while preserving their original form (#536).
* Include responsive image candidates from `img[srcset]` and `picture source[srcset]`, alongside `img[src]`, with resolved, deduplicated URLs in document order. All candidates are included regardless of media conditions or device density; responsive candidates use downloaded dimensions for ranking (#269).
* Add opt-in image validation with `download_image_options: { reject_invalid_images: true }` to omit invalid collection and suggested images, allowing `images.best` to fall back to another image. Use `fetch_all_image_meta: true` and `images.with_metadata` for validity information without filtering. Both options respect download controls and share a cached validation budget; unchecked images retain unknown validity (#271).
* Add opt-in `max_html_bytes` to reject oversized HTML before parsing (#273).
* Add opt-in `images.with_details` to report image type and file size alongside dimensions (#268). When image validation is enabled, it reuses the validation lookups and, with `reject_invalid_images`, omits images that failed validation instead of raising for non-HTTP URLs. Validation now normalizes non-ASCII image URLs before requesting them, and URLs found invalid without a request no longer count toward `max_image_downloads` (#537).
* Add `iframes` to expose each iframe's original attributes, and `iframe_sources` to resolve their source URLs (#222).

## [Changes in 5.20.0](https://github.com/jaimeiniesta/metainspector/compare/v5.19.0...v5.20.0)

* Security: route image size downloads through Faraday so they respect configured network and redirect controls. Add optional `url_filter:` to validate the initial page URL, HEAD requests, image URLs and every redirect destination before requesting them. Returning `false` or `nil` blocks the request with `MetaInspector::RequestError`; filter exceptions propagate. Only HTTP(S) requests are supported ([GHSA-6vgc-f9v5-8939](https://github.com/jaimeiniesta/metainspector/security/advisories/GHSA-6vgc-f9v5-8939)).
* Accept `faraday_http_cache` inside `faraday_options`, which used to raise `NameError`. The top-level `faraday_http_cache` option still works but is deprecated: it prints a warning once per process. Passing both raises `ArgumentError` (#373).

## [Changes in 5.19.0](https://github.com/jaimeiniesta/metainspector/compare/v5.18.1...v5.19.0)

* Security: stop modifying the `faraday_options` hash passed to MetaInspector. When the same hash was reused, its `redirect` options were deleted after the first request, so a redirect `callback` used to block private hosts only ran once and later requests followed any redirect ([GHSA-mm2p-6q2v-7ph5](https://github.com/jaimeiniesta/metainspector/security/advisories/GHSA-mm2p-6q2v-7ph5)). Frozen option hashes no longer raise `FrozenError`.
* Add `language` to expose the root HTML `lang` attribute, trimming surrounding whitespace and returning `nil` for missing or blank values. Include it in `to_hash` (#121).
* Add opt-in `max_image_downloads` to limit image size lookup attempts while preserving dimensions already available in HTML (#242).
* Add `parsely-title`, `parsely-author`, and `parsely-image-url` fallbacks to `best_title`, `best_author`, and `images.owner_suggested` / `images.best`, preserving existing preferred metadata sources (#214).
* Resolve relative base hrefs against the full document URL, preserving nested paths and non-default ports (#240).
* Skip invalid image URLs in `images.with_size`, preventing `images.best` from failing when FastImage receives a nil URL ([#521](https://github.com/jaimeiniesta/metainspector/issues/521), follow-up to [#359](https://github.com/jaimeiniesta/metainspector/issues/359)).
* Add opt-in `head_first: true` to check content type with HEAD and reject non-HTML files before downloading them (#221).

## [Changes in 5.18.1](https://github.com/jaimeiniesta/metainspector/compare/v5.18.0...v5.18.1)

* Require nokogiri 1.19.5, which fixes three low-severity security advisories.
* Commit Gemfile.lock to the repository, and run CI against the newest allowed dependencies as well.

## [Changes in 5.18.0](https://github.com/jaimeiniesta/metainspector/compare/v5.17.4...v5.18.0)

* Remove support for Ruby 3.2, which reached end of life on 2026-04-01.
* Require Ruby >= 3.3 in the gemspec.

## [Changes in 5.17.4](https://github.com/jaimeiniesta/metainspector/compare/v5.17.3...v5.17.4)

* Require patched versions of dependencies with security advisories: addressable 2.9.1, faraday 2.14.3, faraday-http-cache 2.8 and nokogiri 1.19.4.

## [Changes in 5.17.3](https://github.com/jaimeiniesta/metainspector/compare/v5.17.2...v5.17.3)

* Update faraday-http-cache requirement to allow 3.x.
* Update resolv to 0.8.

## [Changes in 5.17.2](https://github.com/jaimeiniesta/metainspector/compare/v5.17.1...v5.17.2)

* Fix best title and author so empty strings are skipped.
* Update resolv.

## [Changes in 5.17.1](https://github.com/jaimeiniesta/metainspector/compare/v5.17.0...v5.17.1)

* Upgrade addressable and puma dependencies

## [Changes in 5.17.0](https://github.com/jaimeiniesta/metainspector/compare/v5.16.0...v5.17.0)

* Add support for Ruby 4.0
* Remove support for Ruby 3.1
* Several dependencies upgrade

## [Changes in 5.16.0](https://github.com/jaimeiniesta/metainspector/compare/v5.15.0...v5.16.0)

* Upgraded dependencies and supported Ruby versions.

## [Changes in 5.15.0](https://github.com/jaimeiniesta/metainspector/compare/v5.14.0...v5.15.0)

* Added mechanism to use all available options in the `FollowRedirects` Faraday middleware,
https://github.com/jaimeiniesta/metainspector/pull/355 thanks to @bruno-b-martins and @miguelrod

## [Changes in 5.14.0](https://github.com/jaimeiniesta/metainspector/compare/v5.13.0...v5.14.0)

* Several dependency updates, including Addressable 2.8.1 which fixes invalid_byte_sequence exception.

## [Changes in 5.13.0](https://github.com/jaimeiniesta/metainspector/compare/v5.12.1...v5.13.0)

* Remove support for #feed that was deprecated in 5.9
* Add support for Ruby 3.1

## [Changes in 5.12.1](https://github.com/jaimeiniesta/metainspector/compare/v5.12.0...v5.12.1)

* Update dependencies: rubocop, nokogiri

## [Changes in 5.12.0](https://github.com/jaimeiniesta/metainspector/compare/v5.11.2...v5.12.0)

* Support Ruby 3.0

## [Changes in 5.11.2](https://github.com/jaimeiniesta/metainspector/compare/v5.11.1...v5.11.2)

* Relax dependencies to allow minor releases.

## [Changes in 5.11.0](https://github.com/jaimeiniesta/metainspector/compare/v5.11.0...v5.11.1)

* Upgrade to Nokogiri 1.11.0.

## [Changes in 5.11.0](https://github.com/jaimeiniesta/metainspector/compare/v5.10.1...v5.11.0)

* Upgrade to Faraday 1.1.

## [Changes in 5.10.1](https://github.com/jaimeiniesta/metainspector/compare/v5.10.0...v5.10.1)

* Fix for empty base_href. Makes relative links work when base_href is nil but empty ("").
* Drop support for Ruby 2.4, add support for Ruby 2.7.

## [Changes in 5.10](https://github.com/jaimeiniesta/metainspector/compare/v5.9.0...v5.10.0)

* Upgrade to Faraday 1.0.

## [Changes in 5.9](https://github.com/jaimeiniesta/metainspector/compare/v5.8.0...v5.9.0)

* Added #feeds method to retrieve all feeds of a page.
* Adds deprecation warning on #feed method.

## [Changes in 5.8](https://github.com/jaimeiniesta/metainspector/compare/v5.7.0...v5.8.0)

* Added h1..h6 support.

## [Changes in 5.7](https://github.com/jaimeiniesta/metainspector/compare/v5.6.0...v5.7.0)

* Avoids normalizing image URLs. https://github.com/jaimeiniesta/metainspector/pull/241
* Adds `NonHtmlErrorException` instead of `ParserError` https://github.com/jaimeiniesta/metainspector/pull/248

## [Changes in 5.6](https://github.com/jaimeiniesta/metainspector/compare/v5.5.0...v5.6.0)

* New feature: `:encoding` option for force encoding of a parsed document.
* Improvement: make `best_title` and `best_author` work by order of preference, rather than length.

## [Changes in 5.5](https://github.com/jaimeiniesta/metainspector/compare/v5.4.0...v5.5.0)

* New feature: adds `author`, `best_author`.
* Bugfix: adds presence validation for empty string on meta tag image values.
* Improves spider and links checker examples.
* Uses WebMock instead of FakeWeb in tests.

## [Changes in 5.4](https://github.com/jaimeiniesta/metainspector/compare/v5.3.0...v5.4.0)

* Supports Gzipped responses.
* Adds method `best_description` and makes `description` return just the meta description.
* Removes support for Ruby 2.0.0 and adds support for 2.4.0.

## [Changes in 5.3](https://github.com/jaimeiniesta/metainspector/compare/v5.2.0...v5.3.0)

* Returns secondary description if meta description is empty.
* Adds a custom timeout on top of the ones for Faraday, and sets defaults for timeouts.
* Eliminates possible NULL char in HTML which breaks nokogiri.

## [Changes in 5.2](https://github.com/jaimeiniesta/metainspector/compare/v5.1.0...v5.2.0)

* Removes the deprecated `html_content_only` option, and replaces it by `allow_non_html_content`, by default `false`.

## [Changes in 5.1](https://github.com/jaimeiniesta/metainspector/compare/v5.0.0...v5.1.0)

* Deprecates the `html_content_only` option, and turns it on by default.

## [Changes in 5.0](https://github.com/jaimeiniesta/metainspector/compare/v4.7.1...v5.0.0)

* Removes the ExceptionLog, all exceptions are now encapsulated in our own exception classes and
always raised.

## [Changes in 4.7](https://github.com/jaimeiniesta/metainspector/compare/v4.6.0...v4.7.1)

* MetaInspector can be configured to use [Faraday::HttpCache](https://github.com/plataformatec/faraday-http-cache) to cache page responses. For that you should pass the `faraday_http_cache` option with at least the `:store` key, for example:

```ruby
cache = ActiveSupport::Cache.lookup_store(:file_store, '/tmp/cache')
page = MetaInspector.new('http://example.com', faraday_http_cache: { store: cache })
```

* Bugfixes:
  * Parsing of the document is done as soon as it is initialized (just like we do with the request), so
that parsing errors will be catched earlier.
  * Rescues from Faraday::SSLError.

## [Changes in 4.6](https://github.com/jaimeiniesta/metainspector/compare/v4.5.0...v4.6.0)

* Faraday can be passed options via `:faraday_options`. This is useful in cases where we need to
customize the way we request the page, like for example disabling SSL verification, like this:

```ruby
MetaInspector.new('https://example.com')
# Faraday::SSLError: SSL_connect returned=1 errno=0 state=SSLv3 read server certificate B: certificate verify failed

MetaInpector.new('https://example.com', faraday_options: { ssl: { verify: false } })
# Now we can access the page
```

## [Changes in 4.5](https://github.com/jaimeiniesta/metainspector/compare/v4.4.0...v4.5.0)

* The Document API now includes access to head/link elements
    * `page.head_links` returns an array of hashes of all head/links.
    * `page.stylesheets` returns head/links where rel='stylesheet'
    * `page.canonicals` returns head/links where rel='canonical'

* The URL API can remove common tracking parameters from the querystring
    * `url.tracked?` will tell you if the url contains known tracking parameters
    * `url.untracked_url` will return the url with known tracking parameters removed
    * `url.untrack!` will remove the tracking parameters from the url

* The images API has been extended:
    * `page.images.with_size` returns a sorted array (by descending area) of [image_url, width, height]

## [Changes in 4.4](https://github.com/jaimeiniesta/metainspector/compare/v4.3.0...v4.4.0)

* The default headers now include `'Accept-Encoding' => 'identity'` to minimize trouble with servers that respond with malformed compressed responses, [as explained here](https://github.com/lostisland/faraday/issues/337).

## [Changes in 4.3](https://github.com/jaimeiniesta/metainspector/compare/v4.3.0...v4.4.0)

* The Document API has been extended with one new method `page.best_title` that returns the longest text available from a selection of candidates.
* `to_hash` now includes `scheme`, `host`, `root_url`, `best_title` and `description`.

## [Changes in 4.2](https://github.com/jaimeiniesta/metainspector/compare/v4.1.0...v4.2.0)

* The images API has been extended, with two new methods:

  * `page.images.owner_suggested` returns the OG or Twitter image, or `nil` if neither are present.
  * `page.images.largest` returns the largest image found in the page. This uses the HTML height and width attributes as well as the [fastimage](https://github.com/sdsykes/fastimage) gem to return the largest image on the page that has a ratio squarer than 1:10 or 10:1. This usually provides a good alternative to the OG or Twitter images if they are not supplied.

* The criteria for `page.images.best` has changed slightly, we'll now return the largest image instead of the first image if no owner-suggested image is found.

## [Changes in 4.1](https://github.com/jaimeiniesta/metainspector/compare/v4.0.0...v4.1.0)

* Introduces the `:normalize_url` option, which allows to disable URL normalization.

## [Changes in 4.0](https://github.com/jaimeiniesta/metainspector/compare/v3.0.0...v4.0.0)

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

## [Changes in 3.0](https://github.com/jaimeiniesta/metainspector/compare/v2.0.0...v3.0.0)

* The redirect API has been changed, now the `:allow_redirections` option will expect only a boolean, which by default is `true`. That is, no more specifying `:safe`, `:unsafe` or `:all`.
* We've dropped support for Ruby < 2.

Also, we've introduced a new feature:

* Persist cookies across redirects. Now MetaInspector will include the received cookies when following redirects. This fixes some cases where a redirect would fail, sometimes caught in a redirection loop.
