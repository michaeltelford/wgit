# See `bundle exec rake` tasks: `save_page` and `save_site` for saving a web
# fixture to disk; then mock its HTTP response below so it's available to crawl
# in the tests using Wgit. Note that you can mock a response without a fixture.

require_relative 'webmock' # DSL for mocking HTTP responses.

# Custom mock responses, outside of serving a saved fixture.
stub_page 'https://www.google.co.uk'
stub_page 'https://duckduckgo.com'
stub_page 'http://www.bing.com'
stub_page 'https://twitter.com'
stub_redirect 'http://twitter.com', 'https://twitter.com'

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
]

stub_fixtures pages, sites
