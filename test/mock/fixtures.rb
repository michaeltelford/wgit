# See `bundle exec rake` tasks: `save_page` and `save_site` for saving a web
# fixture to disk; then mock its HTTP response below so it's available to crawl
# in the tests using Wgit. Note that you can mock a response without a fixture.

require_relative 'webmock' # DSL for mocking HTTP responses.

# Custom mock responses, outside of serving a saved fixture from disk.
stub_page 'https://www.google.co.uk'
stub_page 'https://duckduckgo.com'
stub_page 'http://www.bing.com'
stub_redirect 'http://twitter.com', 'https://twitter.com'
stub_page 'https://twitter.com'
stub_redirect 'https://cms.org', 'https://example.com/de/page1'
stub_redirect 'https://example.com/de/page1', '/de/folder/page2#anchor-on-page2'
stub_page 'https://example.com/de/folder/page2'
stub_redirect 'http://redirect.com/1', 'http://redirect.com/2' # First redirect.
stub_redirect 'http://redirect.com/2', 'http://redirect.com/3' # Second redirect.
stub_redirect 'http://redirect.com/3', 'http://redirect.com/4' # Third redirect.
stub_redirect 'http://redirect.com/4', 'http://redirect.com/5' # Fourth redirect.
stub_redirect 'http://redirect.com/5', 'http://redirect.com/6' # Fifth redirect.
stub_redirect 'http://redirect.com/6', 'http://redirect.com/7' # Sixth redirect.
stub_page 'http://redirect.com/7'
stub_page 'https://www.xn--ber-goa.com/about'
stub_redirect 'http://test-site.com/sneaky', 'https://motherfuckingwebsite.com/'
stub_page 'http://test-site.com/public/records?q=username', fixture: 'test-site.com/public/records'
stub_page 'http://test-site.com/public/records#top', fixture: 'test-site.com/public/records'
stub_page 'http://ftp.test-site.com', status: 404, fixture: 'test-site.com/not_found'

# Mock responses based on the fixtures saved to disk. Both single webpages and
# full websites are supported.
pages = [
  'https://motherfuckingwebsite.com/',
  'https://wikileaks.org/What-is-Wikileaks.html',
  'https://www.facebook.com',
  'https://static.xx.fbcdn.net/rsrc.php/v3/y1/l/0,cross/NvZ4mNTW3Fd.css',
  'http://altitudejunkies.com',
  'http://www.mountainmadness.com',
  'http://www.adventureconsultants.com',
]

sites = [
  'http://txti.es/',
  'http://www.belfastpilates.co.uk/',
  'http://test-site.com',
]

stub_fixtures pages, sites
