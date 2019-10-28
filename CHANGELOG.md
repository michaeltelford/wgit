# Wgit Change Log

## v0.0.0 (TEMPLATE - DO NOT EDIT)
### Added
- ...
### Changed/Removed
- ...
### Fixed
- ...
---

## v0.5.0
### Added
- A Wgit Wiki! [https://github.com/michaeltelford/wgit/wiki](https://github.com/michaeltelford/wgit/wiki)
- `Wgit::Document#content` alias for `#html`.
- `Wgit::Url#prefix_base` method.
- `Wgit::Url#to_addressable_uri` method.
### Changed/Removed
- Breaking changes: Removed `Wgit::Document#date_crawled` and `#crawl_duration` because both of these methods exist on the `Wgit::Document#url`. Instead, use `doc.url.date_crawled` etc.
- Breaking changes: Added to and moved `Document.define_extension` block params, it's now `|value, source, type|`. The `source` is not what it used to be; it's now `type` - of either `:document` or `:object`. Confused? See the [docs](https://www.rubydoc.info/gems/wgit).
- Breaking changes: Changed `Wgit::Url#prefix_protocol` so that it no longer modifies the receiver.
- Breaking changes: Updated `Wgit::Url#to_anchor` and `#to_query` logic to align with that of `Addressable::URI` e.g. the anchor value no longer contains `#` prefix; and the query value no longer contains `?` prefix.
- Breaking changes: Renamed `Wgit::Url` methods containing `anchor` to now be named `fragment` e.g. `to_anchor` is now called `to_fragment` and `without_anchor` is `without_fragment` etc.
- Breaking changes: Renamed `Wgit::Url#prefix_protocol` to `#prefix_scheme`. The `protocol:` param name remains unchanged.
### Fixed
- Bug in `Wgit::Document#base_url` around the handling of invalid base URL scenarios.
---

## v0.4.1
### Added
- ...
### Changed/Removed
- ...
### Fixed
- A crawl bug that resulted in some servers dropping requests due to the use of Typhoeus's default `User-Agent` header. This has now been changed.
---

## v0.4.0
### Added
- `Wgit::Document#stats` alias `#statistics`.
- `Wgit::Crawler#time_out` logic for long crawls. Can also be set via `initialize`.
- `Wgit::Crawler#last_response#redirect_count` method logic.
- `Wgit::Crawler#last_response#total_time` method logic.
- `Wgit::Utils.fetch(hash, key, default = nil)` method which tries multiple key formats before giving up e.g. `:foo, 'foo', 'FOO'` etc.
### Changed/Removed
- Breaking changes: Updated `Wgit::Crawler` crawl logic to use `typhoeus` instead of `Net:HTTP`. Users should see a significant improvement in crawl speed as a result. This means that `Wgit::Crawler#last_response` is now of type `Typhoeus::Response`. See https://rubydoc.info/gems/typhoeus/Typhoeus/Response for more info.
### Fixed
- ...
---

## v0.3.0
### Added
- `Url#crawl_duration` method.
- `Document#crawl_duration` method.
- `Benchmark.measure` to Crawler logic to set `Url#crawl_duration`.
### Changed/Removed
- Breaking changes: Updated data model to embed the full 'url' object inside the documents object.
- Breaking changes: Updated data model by removing documents 'score' attribute.
### Fixed
- ...
---

## v0.2.0
This version of Wgit see's a major refactor of the code base involving multiple changes to method names and their signatures (optional parameters turned into named parameters in most cases). A list of the breaking changes are below including how to fix any breakages; but if you're having issues with the upgrade see the documentation at: https://www.rubydoc.info/gems/wgit
### Added
- `Wgit::Url#absolute?` method.
- `Wgit::Url#relative? base: url` support.
- `Wgit::Database.connect` method (alias for `Wgit::Database.new`).
- `Wgit::Database#search` and `Wgit::Document#search` methods now support `case_sensitive:` and `whole_sentence:` named parameters.
### Changed/Removed
- Breaking changes: Renamed the following `Wgit` and `Wgit::Indexer` methods: `Wgit.index_the_web` to `Wgit.index_www`, `Wgit::Indexer.index_the_web` to `Wgit::Indexer.index_www`, `Wgit.index_this_site` to `Wgit.index_site`, `Wgit::Indexer.index_this_site` to `Wgit::Indexer.index_site`, `Wgit.index_this_page` to `Wgit.index_page`, `Wgit::Indexer.index_this_page` to `Wgit::Indexer.index_page`.
- Breaking changes: All `Wgit::Indexer` methods now take named parameters.
- Breaking changes: The following `Wgit::Url` method signatures have changed: `initialize` aka `new`,
- Breaking changes: The following `Wgit::Url` class methods have been removed: `.validate`, `.valid?`, `.prefix_protocol`, `.concat` in favour of instance methods by the same names.
- Breaking changes: The following `Wgit::Url` instance methods/aliases have been changed/removed: `#to_protocol` (now `#to_scheme`), `#to_query_string` and `#query_string` (now `#to_query`), `#relative_link?` (now `#relative?`), `#without_query_string` (now `#without_query`), `#is_query_string?` (now `#query?`).
- Breaking changes: The database connection string is now passed directly to `Wgit::Database.new`; or in its absence, obtained from `ENV['WGIT_CONNECTION_STRING']`. See the `README.md` section entitled: `Practical Database Example` for an example.
- Breaking changes: The following `Wgit::Database` instance methods now take named parameters: `#urls`, `#crawled_urls`, `#uncrawled_urls`, `#search`.
- Breaking changes: The following `Wgit::Document` instance methods now take named parameters: `#to_h`, `#to_json`, `#search`, `#search!`.
- Breaking changes: The following `Wgit::Document` instance methods/aliases have been changed/removed: `#internal_full_links` (now `#internal_absolute_links`).
- Breaking changes: Any `Wgit::Document` method alias for returning links containing the word `relative` has been removed for clarity. Use `#internal_links`, `#internal_absolute_links` or `#external_links` instead.
- Breaking changes: `Wgit::Crawler` instance vars `@docs` and `@urls` have been removed causing the following instance methods to also be removed: `#urls=`, `#[]`, `#<<`. Also, `.new` aka `#initialize` now requires no params.
- Breaking changes: `Wgit::Crawler.new` now takes an optional `redirect_limit:` parameter. This is now the only way of customising the redirect crawl behavior. `Wgit::Crawler.redirect_limit` no longer exists.
- Breaking changes: The following `Wgit::Crawler` instance methods signatures have changed: `#crawl_site` and `#crawl_url` now require a `url` param (which no longer defaults), `#crawl_urls` now requires one or more `*urls` (which no longer defaults).
- Breaking changes: The following `Wgit::Assertable` method aliases have been removed: `.type`, `.types` (use `.assert_types` instead) and `.arr_type`, `.arr_types` (use `.assert_arr_types` instead).
- Breaking changes: The following `Wgit::Utils` methods now take named parameters: `.to_h` and `.printf_search_results`.
- Breaking changes: `Wgit::Utils.printf_search_results`'s method signature has changed; the search parameters have been removed. Before calling this method you must call `doc.search!` on each of the `results`. See the docs for the full details.
- `Wgit::Document` instances can now be instantiated with `String` Url's (previously only `Wgit::Url`'s).
### Fixed
- ...
---

## v0.0.18
### Added
- `Wgit::Url#to_brand` method and updated `Wgit::Url#is_relative?` to support it.
### Changed/Removed
- Updated certain classes by changing some `private` methods to `protected`.
### Fixed
- ...
---

## v0.0.17
### Added
- Support for `<base>` element in `Wgit::Document`'s.
- New `Wgit::Url` methods: `without_query_string`, `is_query_string?`, `is_anchor?`, `replace` (override of `String#replace`).
### Changed/Removed
- Breaking changes: Removed `Wgit::Document#internal_links_without_anchors` method.
- Breaking changes (potentially): `Wgit::Url`'s are now replaced with the redirected to Url during a crawl.
- Updated `Wgit::Document#base_url` to support an optional `link:` named parameter.
- Updated `Wgit::Crawler#crawl_site` to allow the initial url to redirect to another host.
- Updated `Wgit::Url#is_relative?` to support an optional `domain:` named parameter.
### Fixed
- Bug in `Wgit::Document#internal_full_links` affecting anchor and query string links including those used during `Wgit::Crawler#crawl_site`.
- Bug causing an 'Invalid URL' error for `Wgit::Crawler#crawl_site`.
---

## v0.0.16
### Added
- Added `Wgit::Url.parse` class method as alias for `Wgit::Url.new`.
### Changed/Removed
- Breaking changes: Removed `Wgit::Url.relative_link?` (class method). Use `Wgit::Url#is_relative?` (instance method) instead e.g. `Wgit::Url.new('/blah').is_relative?`.
### Fixed
- Several URI related bugs in `Wgit::Url` affecting crawls.
---

## v0.0.15
### Added
- Support for IRI's (non ASCII based URL's).
### Changed/Removed
- Breaking changes: Removed `Document` and `Url#to_hash` aliases. Call `to_h` instead.
### Fixed
- Bug in `Crawler#crawl_site` where an internal redirect to an external site's page was being followed.
---

## v0.0.14
### Added
- `Indexer#index_this_page` method.
### Changed/Removed
- Breaking Changes: `Wgit::CONNECTION_DETAILS` now only requires `DB_CONNECTION_STRING`.
### Fixed
- Found and fixed a bug in `Document#new`.
---
