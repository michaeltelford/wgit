# Wgit Change Log

## v0.0.0 (TEMPLATE - DO NOT EDIT)
### Added
- ...
### Changed/Removed
- ...
### Fixed
- ...
---

## v0.2.0
This version of Wgit see's a major refactor of the code base involving multiple changes to method names and their signatures (optional parameters turned into named parameters in most cases). A list of the breaking changes are below including how to fix any breakages; but if you're having issues with the upgrade see the documentation at: https://www.rubydoc.info/gems/wgit
### Added
- `Wgit::Database.connect` method (alias for `Wgit::Database.new`).
- `Wgit::Url#absolute?` method.
- `Wgit::Url#relative? base: url` support.
- `case_sensitive:` and `whole_sentence:` support to `Database#search` and `Document#search` methods.
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
- `Wgit::Document` instances can now be instantiated with `String` Url's (previously only `Wgit::Url`'s).
- `Wgit::Utils.printf_search_results`'s method signature has changed; the search parameters have been removed. Before calling this method you must call `doc.search!` on each of the `results`. See the docs for the full details.
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
