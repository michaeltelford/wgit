# Wgit Change Log

## v0.0.0 [- BREAKING CHANGES] (TEMPLATE - DO NOT EDIT)
### Added
- ...
### Changed/Removed
- ...
### Fixed
- ...
---

## v0.12.0 - BREAKING CHANGES
A big release with several breaking changes, not all of which can be listed below.
### Added
- `Wgit::Document#nearest_fragment` method which allows you to search for the nearest fragement (#blah) to a piece of text and/or element type.
- `Wgit::Database::DatabaseAdapter` class to allow the easy development of other database adapters that work with Wgit.
- `Wgit::Database::InMemory` database adapter class and logic for quick and easy usage of Wgit on the fly (without needing a MongoDB instance to be running). This also serves as an example of how to write your own database adapter class.
- `Wgit::Model.search_fields` and `.set_search_fields` for setting which search fields are used in document and database adapter searches.
- `Wgit::HTMLToText` class and logic for extracting text from a HTML string. This is now how a `Wgit::Document` extracts its text for searching etc. This class is different in that it not only focuses on the elements we specify, but also applies those elements display in how it delimits where one sentence ends and the next starts e.g. `<span>` is `:inline` etc.
- `Wgit::Model.include_doc_html` and `include_doc_score` methods to set in one place if html/score is included in the corresponding document model output.
- `Wgit::Assertable#common_arr_types` method.
- `Wgit::Utils.pprint(display:)` param to turn off all logs easily (by setting from ENV etc).
- `Wgit::Crawler#crawl_site(max_pages:)` param to quit the crawl early.
### Changed/Removed
- Update Wgit to work with ruby v3 and above, removed support for older versions.
- Removed default extractors `meta_robots` and `meta_wgit` without losing any functionality.
- `Wgit::Database::Model` is now moved up a level to become `Wgit::Model`.
- `Wgit::Database` is now `Wgit::Database::MongoDB` and is alised to `Wgit::Database.adapter_class`.
- Renamed any `Wgit::Database` and `Wgit::DSL` methods called `#clear_*` to be `#empty_*`.
- Moved `Wgit::MongoDB#search!` to `Wgit::DSL#search`.
- Renamed `Wgit::MongoDB#search_text` to `Wgit::Database::MongoDB#search!`.
- Reworked `Wgit::DSL` methods to accept a database param instead of a connection_string. This offers better flexibility.
- Updated the Wgit `Dockerfile` to pull from `mongo:latest`.
- `Wgit::Document` now has the following search methods: `#search`, `#search_text`, `#search_text!`. See their documentation and source code for more information.
- `Wgit::Document.define_extractor` now accepts a `nil` xpath parameter which omits the xpath search.
### Fixed
- Issue [Document#search only searches the text](https://github.com/michaeltelford/wgit/issues/2)
- Issue [Document#search doesn't find certain text](https://github.com/michaeltelford/wgit/issues/20)
---

## v0.11.0 - BREAKING CHANGES
This release is a biggie with the main headline being the introduction of robots.txt support (see below). This release introduces several breaking changes so take care when updating your current version of Wgit.
### Added
- Ability to prevent indexing via `robots.txt` and `noindex` values in HTML `meta` elements and HTTP response header `X-Robots-Tag`. See new class `Wgit::RobotsParser` and the updated `Wgit::Indexer#index_*` methods. Also see the [wiki article](https://github.com/michaeltelford/wgit/wiki/How-To-Prevent-Indexing) on the subject.
- `Wgit::RobotsParser` class for parsing `robots.txt` files.
- `Wgit::Response#no_index?` and `Wgit::Document#no_index?` methods (see wiki article above).
- Added two new default extractors which extract robots meta elements for use in `Wgit::Document#no_index?`.
- Added `Wgit::Document.to_h_ignore_vars` Array for user manipulation.
- Added `Wgit::Utils.pprint` method to aid debugging.
- Added `Wgit::Utils.sanitize_url` method.
- Added `Wgit::Indexer#index_www(max_urls_per_iteration:, ...)` param.
- Added `Wgit::Url#redirects` and `#redirects=` methods.
- Added `Wgit::Url#redirects_journey` used by `Wgit::Indexer` to insert a Url and it's redirects.
- Added `Wgit::Database#bulk_upsert` which `Wgit::Indexer` now uses where possible. This reduces the total database calls made during an index operation.
### Changed/Removed
- Updated `Wgit::Indexer#index_*` methods to honour index prevention methods (see the [wiki article](https://github.com/michaeltelford/wgit/wiki/How-To-Prevent-Indexing)).
- Updated `Wgit::Utils.sanitize*` methods so they no longer modify the receiver.
- Updated `Wgit::Crawler#crawl_url` to always return the crawled `Wgit::Document`. If relying on `nil` in your code, you should now use `doc.empty?` instead.
- Updated `Wgit::Indexer` method logs.
- Updated/added custom class `#inspect` methods.
- Renamed `Wgit::Utils.printf_search_results` to `pprint_search_results`.
- Renamed `Wgit::Url#concat` to `#join`. The `#concat` method is now `String#concat`.
- Updated `Wgit::Indexer` methods to now write external Urls to the Database as: `doc.external_urls.map(&:to_origin)` meaning `http://example.com/about` becomes `http://example.com`.
- Updated the following methods to no longer omit trailing slashes from Urls: `Wgit::Url` - `#to_path`, `#omit_base`, `#omit_origin` and `Wgit::Document` - `#internal_links`, `#internal_absolute_links`, `#external_links`. For an average website, this results in ~30% less network requests when crawling.
- Updated Ruby version to `3.3.0`.
- Updated all bundle dependencies to latest versions, see `Gemfile.lock` for exact versions.
### Fixed
- `Wgit::Crawler#crawl_site` now internally records all redirects for a given Url.
- `Wgit::Crawler#crawl_site` infinite loop when using Wgit on a Ruby version > `3.0.2`.
- Various other minor fixes/improvements throughout the code base.
---

## v0.10.8
### Added
- Custom `#inspect` methods to `Wgit::Url` and `Wgit::Document` classes.
- `Document.remove_extractors` method, which removes all default and defined extractors.

### Changed/Removed
- ...
### Fixed
- ...
---

## v0.10.7
### Added
- ...
### Changed/Removed
- ...
### Fixed
- Security vulnerabilities by updating gem dependencies.
---

## v0.10.6
### Added
- `Wgit::DSL` method `#crawl_url` (aliased to `#crawl`).
### Changed/Removed
- Added a `&block` param to `Wgit::Document#extract`, which gets passed to `#extract_from_html`.
### Fixed
- ...
---

## v0.10.5
### Added
- `Database#last_result` getter method to return the most recent raw mongo result.
### Changed/Removed
- ...
### Fixed
- ...
---

## v0.10.4
### Added
- `Database#search_text` method which returns a Hash of `url => text_results` instead of `Wgit::Documents` (like `#search`).
### Changed/Removed
- ...
### Fixed
- ...
---

## v0.10.3
### Added
- ...
### Changed/Removed
- Changed `Database#create_collections` and `#create_unique_indexes` by removing `rescue nil` from their database operations. Now any underlying errors with the database client are not masked.
### Fixed
- ...
---

## v0.10.2
### Added
- `Wgit::Base#setup` and `#teardown` methods (lifecycle hooks) that can be overridden by subclasses.
### Changed/Removed
- ...
### Fixed
- ...
---

## v0.10.1
### Added
- Support for Ruby 3.
### Changed/Removed
- Removed support for Ruby 2.5 (as it's too old).
### Fixed
- ...
---

## v0.10.0
### Added
- `Wgit::Url#scheme_relative?` method.
### Changed/Removed
- Breaking change: Changed method signature of `Wgit::Url#prefix_scheme` by making the previously named parameter a defaulted positional parameter. Remove the `protocol` named parameter for the old behaviour.
### Fixed
- [Scheme-relative bug](https://github.com/michaeltelford/wgit/issues/10) by adding support for scheme-relative URL's.
---

## v0.9.0
This release is a big one with the introduction of a `Wgit::DSL` and Javascript parse support. The `README` has been revamped as a result with new usage examples. And all of the wiki articles have been updated to reflect the latest code base.
### Added
- `Wgit::DSL` module providing a wrapper around the underlying classes and methods. Check out the `README` for example usage.
- `Wgit::Crawler#parse_javascript` which when set to `true` uses Chrome to parse a page's Javascript before returning the fully rendered HTML. This feature is disabled by default.
- `Wgit::Base` class to inherit from, acting as an alternative form of using the DSL.
- `Wgit::Utils.sanitize` which calls `.sanitize_*` underneath.
- `Wgit::Crawler#crawl_site` now has a `follow:` named param - if set, it's xpath value is used to retrieve the next urls to crawl. Otherwise the `:default` is used (as it was before). Use this to override how the site is crawled.
- `Wgit::Database` methods: `#clear_urls`, `#clear_docs`, `#clear_db`, `#text_index`, `#text_index=`, `#create_collections`, `#create_unique_indexes`, `#docs`, `#get`, `#exists?`, `#delete`, `#upsert`.
- `Wgit::Database#clear_db!` alias.
- `Wgit::Document` methods: `#at_xpath`, `#at_css` - which call nokogiri underneath.
- `Wgit::Document#extract` method to perform one off content extractions.
- `Wgit::Indexer#index_urls` method which can index several urls in one call.
- `Wgit::Url` methods: `#to_user`, `#to_password`, `#to_sub_domain`, `#to_port`, `#omit_origin`, `#index?`.
### Changed/Removed
- Breaking change: Moved all `Wgit.index*` convienence methods into `Wgit::DSL`.
- Breaking change: Removed `Wgit::Url#normalise`, use `#normalize` instead.
- Breaking change: Removed `Wgit::Database#num_documents`, use `#num_docs` instead.
- Breaking change: Removed `Wgit::Database#length` and `#count`, use `#size` instead.
- Breaking change: Removed `Wgit::Database#document?`, use `#doc?` instead.
- Breaking change: Renamed `Wgit::Indexer#index_page` to `#index_url`.
- Breaking change: Renamed `Wgit::Url.parse_or_nil` to be `.parse?`.
- Breaking change: Renamed `Wgit::Utils.process_*` to be `.sanitize_*`.
- Breaking change: Renamed `Wgit::Utils.remove_non_bson_types` to be `Wgit::Model.select_bson_types`.
- Breaking change: Changed `Wgit::Indexer.index*` named param default from `insert_externals: true` to `false`. Explicitly set it to `true` for the old behaviour.
- Breaking change: Renamed `Wgit::Document.define_extension` to `define_extractor`. Same goes for `remove_extension -> remove_extractor` and `extensions -> extractors`. See the docs for more information.
- Breaking change: Renamed `Wgit::Document#doc` to `#parser`.
- Breaking change: Renamed `Wgit::Crawler#time_out` to `#timeout`. Same goes for the named param passed to `Wgit::Crawler.initialize`.
- Breaking change: Refactored `Wgit::Url#relative?` now takes `:origin` instead of `:base` which takes the port into account. This has a knock on effect for some other methods too - check the docs if you're getting parameter errors.
- Breaking change: Renamed `Wgit::Url#prefix_base` to `#make_absolute`.
- Updated `Utils.printf_search_results` to return the number of results.
- Updated `Wgit::Indexer.new` which can now be called without parameters - the first param (for a database) now defaults to `Wgit::Database.new` which works if `ENV['WGIT_CONNECTION_STRING']` is set.
- Updated `Wgit::Document.define_extractor` to define a setter method (as well as the usual getter method).
- Updated `Wgit::Document#search` to support a `Regexp` query (in addition to a String).
### Fixed
- [Re-indexing bug](https://github.com/michaeltelford/wgit/issues/8) so that indexing content a 2nd time will update it in the database - before it simply disgarded the document.
- `Wgit::Crawler#crawl_site` params `allow/disallow_paths` values can now start with a `/`.
---

## v0.8.0
### Added
- To the range of `Wgit::Document.text_elements`. Now (only and) all visible page text should be extracted into `Wgit::Document#text` successfully.
- `Wgit::Document#description` default extension.
- `Wgit::Url.parse_or_nil` method.
### Changed/Removed
- Breaking change: Renamed `Document#stats[:text_snippets]` to be `:text`.
- Breaking change: `Wgit::Document.define_extension`'s block return value now becomes the `var` value, even when `nil` is returned. This allows `var` to be set to `nil`.
- Potential breaking change: Renamed `Wgit::Response#crawl_time` (alias) to be `#crawl_duration`.
- Updated `Wgit::Crawler::SUPPORTED_FILE_EXTENSIONS` to be `Wgit::Crawler.supported_file_extensions`, making it configurable. Now you can add your own URL extensions if needed.
- Updated the Wgit core extension `String#to_url` to use `Wgit::Url.parse` allowing instances of `Wgit::Url` to returned as is. This also affects `Enumerable#to_urls` in the same way.
### Fixed
- An issue where too much `Wgit::Document#text` was being extracted from the HTML. This was fixed by reverting the recent commit: "Document.text_elements_xpath is now `//*/text()`".
---

## v0.7.0
### Added
- `Wgit::Indexer.new` optional `crawler:` named param.
- `bin/wgit` executable; available after `gem install wgit`. Just type `wgit` at the command line for an interactive shell session with the Wgit gem already loaded.
- `Document.extensions` returning a Set of all defined extensions.
### Changed/Removed
- Potential breaking changes: Updated the default search param from `whole_sentence: false` to `true` across all search methods e.g. `Wgit::Database#search`, `Wgit::Document#search` `Wgit.indexed_search` etc. This brings back more relevant search results by default.
- Updated the Docker image to now include index names; making it easier to identify them.
### Fixed
- ...
---

## v0.6.0
### Added
- Added `Wgit::Utils.proces_arr encode:` param.
### Changed/Removed
- Breaking changes: Updated `Wgit::Response#success?` and `#failure?` logic.
- Breaking changes: Updated `Wgit::Crawler` redirect logic. See the [docs](https://www.rubydoc.info/github/michaeltelford/wgit/Wgit/Crawler#crawl_url-instance_method) for more info.
- Breaking changes: Updated `Wgit::Crawler#crawl_site` path params logic to support globs e.g. `allow_paths: 'wiki/*'`. See the [docs](https://www.rubydoc.info/github/michaeltelford/wgit/Wgit/Crawler#crawl_site-instance_method) for more info.
- Breaking changes: Refactored references of `encode_html:` to `encode:` in the `Wgit::Document` and `Wgit::Crawler` classes.
- Breaking changes: `Wgit::Document.text_elements_xpath` is now `//*/text()`. This means that more text is extracted from each page and you can no longer be selective of the text elements on a page.
- Improved `Wgit::Url#valid?` and `#relative?`.
### Fixed
- Bug fix in `Wgit::Crawler#crawl_site` where `*.php` URLs weren't being crawled. The fix was to implement `Wgit::Crawler::SUPPORTED_FILE_EXTENSIONS`.
- Bug fix in `Wgit::Document#search`.
---

## v0.5.1
### Added
- `Wgit.version_str` method.
### Changed/Removed
- Switched to optimistic dependency versioning.
### Fixed
- Bug in `Wgit::Url#concat`.
---

## v0.5.0
### Added
- A Wgit Wiki! [https://github.com/michaeltelford/wgit/wiki](https://github.com/michaeltelford/wgit/wiki)
- `Wgit::Document#content` alias for `#html`.
- `Wgit::Url#prefix_base` method.
- `Wgit::Url#to_addressable_uri` method.
- Support for partially crawling a site using `Wgit::Crawler#crawl_site(allow_paths: [])` or `disallow_paths:`.
- `Wgit::Url#+` as alias for `#concat`.
- `Wgit::Url#invalid?` method.
- `Wgit.version` method.
- `Wgit::Response` class containing adapter agnostic HTTP response logic.
### Changed/Removed
- Breaking changes: Removed `Wgit::Document#date_crawled` and `#crawl_duration` because both of these methods exist on the `Wgit::Document#url`. Instead, use `doc.url.date_crawled` etc.
- Breaking changes: Added to and moved `Document.define_extension` block params, it's now `|value, source, type|`. The `source` is not what it used to be; it's now `type` - of either `:document` or `:object`. Confused? See the [docs](https://www.rubydoc.info/gems/wgit).
- Breaking changes: Changed `Wgit::Url#prefix_protocol` so that it no longer modifies the receiver.
- Breaking changes: Updated `Wgit::Url#to_anchor` and `#to_query` logic to align with that of `Addressable::URI` e.g. the anchor value no longer contains `#` prefix; and the query value no longer contains `?` prefix.
- Breaking changes: Renamed `Wgit::Url` methods containing `anchor` to now be named `fragment` e.g. `to_anchor` is now called `to_fragment` and `without_anchor` is `without_fragment` etc.
- Breaking changes: Renamed `Wgit::Url#prefix_protocol` to `#prefix_scheme`. The `protocol:` param name remains unchanged.
- Breaking changes: Renamed all `Wgit::Url` methods starting with `without_*` to `omit_*`.
- Breaking changes: `Wgit::Indexer` no longer inserts invalid external URL's (to be crawled at a later date).
- Breaking changes: `Wgit::Crawler#last_response` is now of type `Wgit::Response`. You can access the underlying `Typhoeus::Response` object with `crawler.last_response.adapter_response`.
### Fixed
- Bug in `Wgit::Document#base_url` around the handling of invalid base URL scenarios.
- Several bugs in `Wgit::Database` class caused by the recent changes to the data model (in version 0.3.0).
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
- Breaking changes: Updated data model to embed the full `url` object inside the documents object.
- Breaking changes: Updated data model by removing documents `score` attribute.
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
