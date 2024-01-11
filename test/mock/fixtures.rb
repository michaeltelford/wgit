# See `toys -s save` for tasks on saving a web fixture to disk;
# then mock it's HTTP response below so it's available to crawl in the tests
# using Wgit. Note that you can mock a response without a saved fixture.

require_relative 'webmock' # DSL for mocking HTTP responses.

# Custom mock responses, outside of serving a saved fixture from disk.
stub_page 'https://search.yahoo.com'
stub_page 'https://www.google.co.uk'
stub_page 'http://www.bing.com'
stub_redirect 'http://twitter.com', 'https://twitter.com'
stub_page 'https://twitter.com'
stub_redirect 'https://cms.org', 'https://example.com/de/page1'
stub_redirect 'https://example.com/de/page1', '/de/folder/page2#blah-on-page2'
stub_page 'https://example.com/de/folder/page2#blah-on-page2'
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
stub_redirect 'http://test-site.com/ftp', 'http://ftp.test-site.com'
stub_not_found 'http://ftp.test-site.com'
stub_redirect 'http://test-site.com/smtp', 'http://smtp.test-site.com'
stub_page 'http://smtp.test-site.com'
stub_redirect 'http://myserver.com', 'http://www.myserver.com'
stub_redirect 'http://www.myserver.com', 'http://test-site.com'
stub_timeout 'http://doesnt_exist/'
stub_timeout 'http://test-site.com/doesntexist'
stub_page 'http://odd-extension.com/other.html5', body: '<p>Hello world</p>'
stub_page 'http://fonts.googleapis.com'

# Mock robots.txt requests.
stub_not_found 'http://txti.es/robots.txt'
stub_not_found 'http://quotes.toscrape.com/robots.txt'
stub_not_found 'http://test-site.com/robots.txt'
stub_not_found 'https://motherfuckingwebsite.com/robots.txt'
stub_not_found 'http://link-to-robots-txt.com/robots.txt'
stub_request(:get, 'http://robots.txt.com/account').
  to_return(status: 200, headers: { 'X-Robots-Tag': 'noindex' }, body: '<p>Robots account</p>')

# Mock a website whose's content gets updated (between indexes).
stub_request(:get, 'http://www.content-updates.com').
  to_return({ body: 'Original content' }, { body: 'Updated content' })

# Match all *.jpg URL's for belfastpilates.co.uk.
stub_request(:get, Regexp.new('http://www.belfastpilates.co.uk/(.*).(?:jpg|jpeg)'))

# Mock responses based on individual files saved to disk. The URL should match
# the file name (minus the scheme prefix and .html extension suffix).
pages = [
  'https://motherfuckingwebsite.com/',
  'https://wikileaks.org/What-is-Wikileaks.html',
  'https://www.facebook.com',
  'https://static.xx.fbcdn.net/rsrc.php/v3/y1/l/0,cross/NvZ4mNTW3Fd.css',
  'http://altitudejunkies.com',
  'http://www.mountainmadness.com',
  'http://www.adventureconsultants.com',
  'http://odd-extension.com',
  'http://link-to-robots-txt.com'
]

# Mock sites based on a collection of files saved in a directory.
# NOTE: URL's listed below MUST NOT have a path, only a scheme and host.
sites = [
  'http://txti.es/',
  'http://www.belfastpilates.co.uk/',
  'http://test-site.com',
  'http://quotes.toscrape.com/',
  'http://robots.txt.com',
  'http://no-index.com'
]

stub_fixtures pages, sites
