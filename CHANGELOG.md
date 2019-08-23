# Wgit Change Log

## v0.0.0 (TEMPLATE - DO NOT EDIT)
### Added
- ...
### Changed/Removed
- ...
### Fixed
- ...
---

## v0.0.17
### Added
- Support for `<base>` element in `Wgit::Document`'s.
### Changed/Removed
- Breaking changes: Removed `Wgit::Document#internal_links_without_anchors` method.
### Fixed
- ...
---

## v0.0.16
### Added
- Added `Url.parse` class method as alias for `Url.new`.
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
