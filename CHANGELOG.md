# MetaInpector Changelog

## Changes in 4.5

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

## Changes in 4.4

The default headers now include `'Accept-Encoding' => 'identity'` to minimize trouble with servers that respond with malformed compressed responses, [as explained here](https://github.com/lostisland/faraday/issues/337).

## Changes in 4.3

* The Document API has been extended with one new method `page.best_title` that returns the longest text available from a selection of candidates.
* `to_hash` now includes `scheme`, `host`, `root_url`, `best_title` and `description`.

## Changes in 4.2

* The images API has been extended, with two new methods:

  * `page.images.owner_suggested` returns the OG or Twitter image, or `nil` if neither are present.
  * `page.images.largest` returns the largest image found in the page. This uses the HTML height and width attributes as well as the [fastimage](https://github.com/sdsykes/fastimage) gem to return the largest image on the page that has a ratio squarer than 1:10 or 10:1. This usually provides a good alternative to the OG or Twitter images if they are not supplied.

* The criteria for `page.images.best` has changed slightly, we'll now return the largest image instead of the first image if no owner-suggested image is found.

## Changes in 4.1

* Introduces the `:normalize_url` option, which allows to disable URL normalization.

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
