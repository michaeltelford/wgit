require_relative 'helpers/test_helper'

# Crawl the site's index page for <a> tags that link to jpg's.
class ImageCrawler < Wgit::Crawler
  def get_internal_links(doc, allow_paths: nil, disallow_paths: nil)
    doc.internal_absolute_links
       .select { |link| %w[jpg jpeg].include?(link.to_extension) }
  end
end

# Test class for the Crawler methods.
class TestCrawler < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_initialise
    c = Wgit::Crawler.new

    assert_nil c.last_response
    assert_equal 5, c.redirect_limit
    assert_equal 5, c.time_out
    assert c.encode
  end

  def test_initialise__redirect_limit
    c = Wgit::Crawler.new redirect_limit: 3

    assert_nil c.last_response
    assert_equal 3, c.redirect_limit
    assert_equal 5, c.time_out
    assert c.encode
  end

  def test_initialise__time_out
    c = Wgit::Crawler.new time_out: 3

    assert_nil c.last_response
    assert_equal 5, c.redirect_limit
    assert_equal 3, c.time_out
    assert c.encode
  end

  def test_initialise__encode_html
    c = Wgit::Crawler.new encode: false

    assert_nil c.last_response
    assert_equal 5, c.redirect_limit
    assert_equal 5, c.time_out
    refute c.encode
  end

  def test_crawl_url
    # Valid Url.
    c = Wgit::Crawler.new
    url = 'https://duckduckgo.com'.to_url
    doc = c.crawl_url(url) { |d| assert_crawl(d) }
    assert c.last_response.ok?
    assert_equal 'https://duckduckgo.com', url
    assert_equal url, doc.url
    assert_crawl doc

    # Invalid Url.
    c = Wgit::Crawler.new
    url = Wgit::Url.new('doesnt_exist')
    doc = c.crawl_url(url) do |d|
      assert_equal url, d.url
      assert_empty d
    end
    assert_nil doc
    assert c.last_response.failure?
    assert_equal 'doesnt_exist', url
    assert url.crawled
    refute_nil url.date_crawled
    refute_nil url.crawl_duration

    # IRI (non ASCII) Url.
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'https://www.über.com/about'
    doc = c.crawl_url(url) { |d| assert_crawl(d) }
    assert c.last_response.ok?
    assert_equal 'https://www.über.com/about', url
    assert_equal url, doc.url
    assert_crawl doc

    # String instead of Url instance.
    url = 'http://www.bing.com'
    e = assert_raises(StandardError) { c.crawl_url url }
    assert_equal 'Expected: Wgit::Url, Actual: String', e.message
  end

  def test_crawl_url__not_mocked
    # The vlang.io host is not mocked to test the HTTP crawl logic.
    url = 'https://vlang.io/'.to_url
    crawler = Wgit::Crawler.new
    doc = crawler.crawl_url(url)

    assert crawler.last_response.ok?
    assert_equal 'https://vlang.io/', url
    assert_equal url, doc.url
    assert_crawl doc
    assert url.crawled
    refute_nil url.date_crawled
    refute_nil url.crawl_duration
  end

  def test_crawl_url__redirects
    # http://test-site.com/sneaky redirects to https://motherfuckingwebsite.com/.

    # Redirect allowed, url updates on redirect.
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    c.crawl_url(url) do |doc|
      assert_equal 'https://motherfuckingwebsite.com/', doc.url
      refute_empty doc
    end
    assert_equal 'https://motherfuckingwebsite.com/', url

    # Redirect not allowed, url doesn't change.
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    c.crawl_url(url, follow_redirects: false) do |doc|
      assert_equal 'http://test-site.com/sneaky', doc.url
      assert_empty doc
    end
    assert_equal 'http://test-site.com/sneaky', url
  end

  def test_crawl_urls
    # Test several valid Urls.
    c = Wgit::Crawler.new
    urls = [
      'https://duckduckgo.com',
      'https://www.google.co.uk',
      'http://www.bing.com'
    ].to_urls
    i = 0
    doc = c.crawl_urls(*urls) do |d|
      assert c.last_response.ok?
      assert_crawl d
      i += 1
    end
    assert_crawl doc
    assert_equal urls.length, i
    assert_equal urls.last, doc.url

    # Test one valid Url.
    c = Wgit::Crawler.new
    url = 'https://duckduckgo.com'.to_url
    i = 0
    doc = c.crawl_urls(url) do |d|
      assert c.last_response.ok?
      assert_crawl d
      i += 1
    end
    assert_crawl doc
    assert_equal 1, i
    assert_equal url, doc.url

    # Test one invalid Url.
    c = Wgit::Crawler.new
    url = Wgit::Url.new('doesnt_exist')
    doc = c.crawl_urls(url) do |d|
      assert c.last_response.failure?
      assert d.empty?
      assert d.url.crawled
    end
    assert_nil doc
    assert url.crawled
    refute_nil url.date_crawled
    refute_nil url.crawl_duration

    # Test a mixture of valid and invalid Urls.
    c = Wgit::Crawler.new
    urls = [
      'https://duckduckgo.com',
      'doesnt_exist',
      'http://www.bing.com'
    ].to_urls
    i = 0
    c.crawl_urls(*urls) do |d|
      if i == 1
        assert c.last_response.failure?
        assert_empty d
      else
        assert c.last_response.ok?
        assert_crawl d
      end
      i += 1
    end
  end

  def test_crawl_site
    # Test largish site - Wordpress site with disgusting HTML.
    url = Wgit::Url.new 'http://www.belfastpilates.co.uk/'
    c = Wgit::Crawler.new
    assert_crawl_site c, url, 19, 10, expected_pages: [
      'http://www.belfastpilates.co.uk/',
      'http://www.belfastpilates.co.uk/about-us',
      'http://www.belfastpilates.co.uk/about-us/the-team',
      'http://www.belfastpilates.co.uk/about-us/our-facilities',
      'http://www.belfastpilates.co.uk/about-us/testimonials',
      'http://www.belfastpilates.co.uk/privacy-policy',
      'http://www.belfastpilates.co.uk/pilates/what-is-pilates',
      'http://www.belfastpilates.co.uk/pilates/pilates-classes',
      'http://www.belfastpilates.co.uk/pilates/pilates-classes/pilates-classes-timetable',
      'http://www.belfastpilates.co.uk/pilates/pilates-faqs',
      'http://www.belfastpilates.co.uk/physiotheraphy',
      'http://www.belfastpilates.co.uk/latest-news',
      'http://www.belfastpilates.co.uk/contact-us',
      'http://www.belfastpilates.co.uk/official-launch-party',
      'http://www.belfastpilates.co.uk/author/adminbpp',
      'http://www.belfastpilates.co.uk/category/uncategorized',
      'http://www.belfastpilates.co.uk/youre-invited',
      'http://www.belfastpilates.co.uk/gift-vouchers-now-available-to-purchase',
      'http://www.belfastpilates.co.uk/pilates'
    ]

    # Test small site - Static well formed HTML.
    url = Wgit::Url.new 'http://txti.es'
    c = Wgit::Crawler.new
    assert_crawl_site c, url, 7, 8, expected_pages: [
      'http://txti.es',
      'http://txti.es/about',
      'http://txti.es/how',
      'http://txti.es/terms',
      'http://txti.es/images',
      'http://txti.es/barry/json',
      'http://txti.es/images/images'
    ]

    # Test single web page with a single external link.
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    c = Wgit::Crawler.new
    assert_crawl_site c, url, 1, 1, expected_pages: [
      'https://motherfuckingwebsite.com/'
    ], expected_externals: [
      'http://txti.es'
    ]

    # Test custom small site.
    url = Wgit::Url.new 'http://test-site.com'
    c = Wgit::Crawler.new
    assert_crawl_site c, url, 6, 2, expected_pages: [
      'http://test-site.com',
      'http://test-site.com/contact',
      'http://test-site.com/search',
      'http://test-site.com/about',
      'http://test-site.com/public/records',
      'http://test-site.com/public/records?q=username'
    ], expected_externals: [
      'http://test-site.co.uk',
      'http://ftp.test-site.com'
    ]

    # Test custom small site not starting on the index page.
    url = Wgit::Url.new 'http://test-site.com/search'
    c = Wgit::Crawler.new
    assert_crawl_site c, url, 6, 2, expected_pages: [
      'http://test-site.com/search',
      'http://test-site.com/',
      'http://test-site.com/contact',
      'http://test-site.com/about',
      'http://test-site.com/public/records',
      'http://test-site.com/public/records?q=username'
    ], expected_externals: [
      'http://test-site.co.uk',
      'http://ftp.test-site.com'
    ]

    # Test custom small site with an initial host redirect.
    url = Wgit::Url.new 'http://myserver.com' # Redirects to test-site.com.
    c = Wgit::Crawler.new
    assert_crawl_site c, url, 6, 2, expected_pages: [
      'http://test-site.com',
      'http://test-site.com/contact',
      'http://test-site.com/search',
      'http://test-site.com/about',
      'http://test-site.com/public/records',
      'http://test-site.com/public/records?q=username'
    ], expected_externals: [
      'http://test-site.co.uk',
      'http://ftp.test-site.com'
    ]

    # Test that an invalid url returns nil.
    url = Wgit::Url.new 'http://doesnt_exist/'
    c = Wgit::Crawler.new
    assert_nil c.crawl_site(url)
  end

  def test_crawl_site__allow_paths
    url = Wgit::Url.new 'http://www.belfastpilates.co.uk/'
    c = Wgit::Crawler.new
    assert_crawl_site(c, url, 6, 5, expected_pages: [
      'http://www.belfastpilates.co.uk/',
      'http://www.belfastpilates.co.uk/about-us/the-team',
      'http://www.belfastpilates.co.uk/about-us/our-facilities',
      'http://www.belfastpilates.co.uk/about-us/testimonials',
      'http://www.belfastpilates.co.uk/pilates/pilates-classes',
      'http://www.belfastpilates.co.uk/pilates/pilates-classes/pilates-classes-timetable'
    ], allow_paths: [
      'about-us/*',
      'pilates/pilates-classes*'
    ])
  end

  def test_crawl_site__disallow_paths
    url = Wgit::Url.new 'http://www.belfastpilates.co.uk/privacy-policy'
    c = Wgit::Crawler.new
    assert_crawl_site(c, url, 12, 9, expected_pages: [
      'http://www.belfastpilates.co.uk/privacy-policy',
      'http://www.belfastpilates.co.uk/pilates/what-is-pilates',
      'http://www.belfastpilates.co.uk/pilates/pilates-classes/pilates-classes-timetable',
      'http://www.belfastpilates.co.uk/pilates/pilates-faqs',
      'http://www.belfastpilates.co.uk/physiotheraphy',
      'http://www.belfastpilates.co.uk/latest-news',
      'http://www.belfastpilates.co.uk/contact-us',
      'http://www.belfastpilates.co.uk/official-launch-party',
      'http://www.belfastpilates.co.uk/youre-invited',
      'http://www.belfastpilates.co.uk/gift-vouchers-now-available-to-purchase',
      'http://www.belfastpilates.co.uk/pilates',
      'http://www.belfastpilates.co.uk/category/uncategorized'
    ], disallow_paths: [
      'about-us*',
      'pilates/pilates-classes',
      'author/*',
      '/'
    ])
  end

  def test_crawl_site__not_mocked
    # The vlang.io host is not mocked to test the HTTP crawl logic.
    url = 'https://vlang.io/'.to_url
    crawler = Wgit::Crawler.new

    crawled = []
    externals = crawler.crawl_site(url) do |doc|
      assert_crawl(doc)
      crawled << doc.url
    end

    # Because real websites change over time we limit our assertions.
    assert crawler.last_response.ok?

    refute_empty externals
    assert externals.all? { |external| external.instance_of? Wgit::Url }
    assert_nil externals.uniq!

    refute_empty crawled
    assert_nil crawled.uniq!
    assert_equal url, crawled.first

    assert url.crawled
    refute_nil url.date_crawled
    refute_nil url.crawl_duration
  end

  def test_crawl_site__get_internal_links_override
    url = Wgit::Url.new 'http://www.belfastpilates.co.uk/'
    crawled = []

    # We use ImageCrawler defined at the top of the file.
    crawler = ImageCrawler.new encode: false
    crawler.crawl_site(url) do |doc|
      crawled << doc.url
    end

    assert_equal [
      'http://www.belfastpilates.co.uk/',
      'http://www.belfastpilates.co.uk/wp-content/uploads/2016/11/launch.jpg',
      'http://www.belfastpilates.co.uk/wp-content/uploads/2016/11/Belfast-Pilates-Invitation.jpg',
      'http://www.belfastpilates.co.uk/wp-content/uploads/2016/11/Belfast-Pilates-Gift-Voucher.jpg',
      'http://www.belfastpilates.co.uk/wp-content/uploads/2016/09/180-1024x569.jpg',
      'http://www.belfastpilates.co.uk/wp-content/uploads/2016/09/179-1024x569.jpg',
      'http://www.belfastpilates.co.uk/wp-content/uploads/2016/09/185-1024x569.jpg',
      'http://www.belfastpilates.co.uk/wp-content/uploads/2016/09/studio-1024x661.jpg'
    ], crawled
  end

  def test_fetch
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'http://txti.es/'
    html = c.send :fetch, url

    refute_nil c.last_response
    assert c.last_response.ok?
    assert c.last_response.total_time > 0.0
    assert_equal 0, c.last_response.redirect_count
    refute_nil html
    assert url.crawled
    refute_nil url.date_crawled
    refute_nil url.crawl_duration
  end

  def test_fetch__invalid_url
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'doesnt_exist'
    html = c.send :fetch, url

    refute_nil c.last_response
    assert c.last_response.failure?
    assert_equal 0.0, c.last_response.total_time
    assert_equal 0, c.last_response.redirect_count
    assert_nil html
    assert url.crawled
    refute_nil url.date_crawled
    assert_equal 0.0, url.crawl_duration
  end

  def test_resolve__absolute_location
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'http://twitter.com/' # Redirects once to https.

    assert_resolve c, url, 'https://twitter.com'
  end

  def test_resolve__relative_location
    c = Wgit::Crawler.new
    # Redirects twice to https://example.com/de/folder/page2#blah-on-page2.
    # The 2nd redirect is a relative location.
    url = Wgit::Url.new 'https://cms.org'

    assert_resolve c, url, 'https://example.com/de/folder/page2#blah-on-page2'
  end

  def test_resolve__redirect_limit
    c = Wgit::Crawler.new

    # Redirects 5 times - should resolve.
    url = Wgit::Url.new 'http://redirect.com/2'
    resp = Wgit::Response.new
    assert_resolve c, url, 'http://redirect.com/7'

    # Redirects 6 times - should fail.
    url = Wgit::Url.new 'http://redirect.com/1'
    resp = Wgit::Response.new
    e = assert_raises(StandardError) { c.send :resolve, url, resp }
    assert_equal 'Too many redirects, exceeded: 5', e.message
    assert_equal 'http://redirect.com/6', url

    c = Wgit::Crawler.new redirect_limit: 0

    # Disable redirects - should fail for too many redirects.
    url = Wgit::Url.new 'http://twitter.com/'
    resp = Wgit::Response.new
    e = assert_raises(StandardError) { c.send :resolve, url, resp }
    assert_equal 'Too many redirects, exceeded: 0', e.message
    assert_equal 'http://twitter.com/', url

    # Disable redirects - should pass as there's no redirect.
    url = Wgit::Url.new 'https://twitter.com/'
    resp = Wgit::Response.new
    c.send :resolve, url, resp
    assert_equal 'https://twitter.com/', url

    c = Wgit::Crawler.new redirect_limit: 3

    url = Wgit::Url.new 'http://redirect.com/2' # Would pass normally.
    resp = Wgit::Response.new
    e = assert_raises(StandardError) { c.send :resolve, url, resp }
    assert_equal 'Too many redirects, exceeded: 3', e.message
    assert_equal 'http://redirect.com/5', url
  end

  def test_resolve__time_out
    # Unrealistically short time out causes an error.
    c = Wgit::Crawler.new time_out: 0.001
    resp = Wgit::Response.new

    url = Wgit::Url.new 'http://doesnt_exist/' # Mocks a time out.
    e = assert_raises(StandardError) { c.send :resolve, url, resp }
    assert_equal 'No response (within timeout: 0.001 second(s))', e.message
    assert resp.failure?

    # Disable time outs.
    c = Wgit::Crawler.new time_out: 0
    resp = Wgit::Response.new

    url = Wgit::Url.new 'http://test-site.com'
    c.send :resolve, url, resp
    assert resp.ok?
  end

  def test_resolve__string_url
    # All ASCII chars.
    c = Wgit::Crawler.new
    resp = Wgit::Response.new
    url = 'http://test-site.com'
    c.send :resolve, url, resp

    assert_equal 'http://test-site.com', url
    assert resp.ok?

    # Non ASCII chars (IRI String).
    c = Wgit::Crawler.new
    resp = Wgit::Response.new
    url = 'https://www.über.com/about'
    c.send :resolve, url, resp

    assert_equal 'https://www.über.com/about', url
    assert resp.ok?
  end

  def test_resolve__invalid_url
    c = Wgit::Crawler.new
    resp = Wgit::Response.new
    url = 'http://doesnt_exist/'.to_url

    e = assert_raises(StandardError) { c.send(:resolve, url, resp) }
    assert_equal 'No response (within timeout: 5 second(s))', e.message
    assert resp.failure?
  end

  def test_resolve__redirect_allowed_anywhere
    c = Wgit::Crawler.new
    # Redirects once to https://motherfuckingwebsite.com/.
    url = Wgit::Url.new 'http://test-site.com/sneaky'

    assert_resolve c, url, 'https://motherfuckingwebsite.com/'
  end

  def test_resolve__redirect_not_allowed_anywhere
    c = Wgit::Crawler.new
    url = 'http://twitter.com'.to_url
    resp = Wgit::Response.new

    e = assert_raises(StandardError) do
      c.send(:resolve, url, resp, follow_redirects: false)
    end
    assert_equal 'Redirect not allowed: https://twitter.com', e.message
    assert_equal 'http://twitter.com', url
    assert resp.redirect?
  end

  def test_resolve__redirect_allowed_within_host__success
    c = Wgit::Crawler.new
    # Redirects to https://twitter.com which is on same host.
    url = Wgit::Url.new 'http://twitter.com'

    assert_resolve c, url, 'https://twitter.com', follow_redirects: :host
  end

  def test_resolve__redirect_allowed_within_host__failure
    c = Wgit::Crawler.new
    resp = Wgit::Response.new
    # Redirects to http://ftp.test-site.com which is outside of host.
    url = Wgit::Url.new 'http://test-site.com/ftp'

    e = assert_raises(StandardError) do
      c.send(:resolve, url, resp, follow_redirects: :host)
    end
    assert_equal "Redirect (outside of host) is not allowed: 'http://ftp.test-site.com'", e.message
    assert_equal 'http://test-site.com/ftp', url
    assert resp.redirect?
  end

  def test_resolve__redirect_allowed_within_domain__success
    c = Wgit::Crawler.new
    # Redirects to http://smtp.test-site.com which is on same domain.
    url = Wgit::Url.new 'http://test-site.com/smtp'

    assert_resolve c, url, 'http://smtp.test-site.com', follow_redirects: :domain
  end

  def test_resolve__redirect_allowed_within_domain__failure
    c = Wgit::Crawler.new
    resp = Wgit::Response.new
    # Redirects twice, first is within domain, 2nd isn't, which fails.
    url = Wgit::Url.new 'http://myserver.com'

    e = assert_raises(StandardError) do
      c.send(:resolve, url, resp, follow_redirects: :domain)
    end
    assert_equal "Redirect (outside of domain) is not allowed: 'http://test-site.com'", e.message
    assert_equal 'http://www.myserver.com', url
    assert resp.redirect?
  end

  def test_resolve__follow_redirect_invalid_param
    c = Wgit::Crawler.new
    url = 'http://twitter.com'.to_url
    resp = Wgit::Response.new

    e = assert_raises(StandardError) do
      # Error for :foo opts param.
      c.send :resolve, url, resp, follow_redirects: :foo
    end
    assert_equal 'Unknown opts param: :foo, use one of: [:base, :host, :domain, :brand]', e.message
    assert_equal 'http://twitter.com', url
    assert resp.redirect?
  end

  def test_resolve__redirect_yielded
    i = 0
    c = Wgit::Crawler.new

    # Redirects twice to 7.
    orig_url = Wgit::Url.new 'http://redirect.com/5'
    resp = Wgit::Response.new
    c.send(:resolve, orig_url, resp) do |url, response, location|
      i += 1
      path = url.to_path.to_i + 1

      assert_instance_of Wgit::Url, url
      assert_instance_of Wgit::Url, location
      assert response.redirect? unless location.empty?

      assert_equal orig_url, url if i == 1
      assert_equal path, location.to_path.to_i unless location.empty?
    end
    assert_instance_of Wgit::Response, resp
    assert resp.ok?
    assert resp.total_time > 0.0
    assert_equal 2, resp.redirect_count
    assert_equal({
      'http://redirect.com/5' => 'http://redirect.com/6',
      'http://redirect.com/6' => 'http://redirect.com/7'
    }, resp.redirections)

    # Doesn't redirect.
    orig_url = Wgit::Url.new 'https://twitter.com'
    resp = Wgit::Response.new
    c.send(:resolve, orig_url, resp) do |url, response, location|
      assert_instance_of Wgit::Url, url
      assert_instance_of Wgit::Url, location
      assert_equal 200, response.code

      assert_equal orig_url, url
      assert_empty location
    end
    assert_instance_of Wgit::Response, resp
    assert resp.ok?
    assert resp.total_time > 0.0
    assert_equal 0, resp.redirect_count
    assert_empty resp.redirections
  end

  def test_get_internal_links
    url = Wgit::Url.new('http://www.mytestsite.com/home')
    html = File.read('test/mock/fixtures/test_doc.html')
    doc = Wgit::Document.new(url, html)
    crawler = Wgit::Crawler.new

    assert_equal [
      'http://www.mytestsite.com/home',
      'http://www.mytestsite.com/home?foo=bar',
      'http://www.mytestsite.com/security.html',
      'http://www.mytestsite.com/about.html',
      'http://www.mytestsite.com/',
      'http://www.mytestsite.com/contact.html',
      'http://www.mytestsite.com/tests.html',
      'http://www.mytestsite.com/blog',
      'http://www.mytestsite.com/contents'
    ], crawler.send(:get_internal_links, doc)

    # Some error scenarios for partial site crawls using paths.
    ex = assert_raises(StandardError) do
      crawler.send(:get_internal_links, doc, allow_paths: [true])
    end
    assert_equal 'The provided paths must all be Strings', ex.message

    ex = assert_raises(StandardError) do
      crawler.send(:get_internal_links, doc, allow_paths: ['', '  '])
    end
    assert_equal 'The provided paths cannot be empty', ex.message
  end

  def test_get_internal_links__with_url_extensions
    url = Wgit::Url.new('http://www.php.com/index.php')
    html = File.read('test/mock/fixtures/php.html')
    doc = Wgit::Document.new(url, html)
    crawler = Wgit::Crawler.new

    assert_equal [
      'http://www.php.com/about.php',
      'http://www.php.com/index.php?foo=bar'
    ], crawler.send(:get_internal_links, doc)

    assert_equal [
      'http://www.php.com/index.php?foo=bar'
    ], crawler.send(:get_internal_links, doc, disallow_paths: '*.php')

    assert_empty crawler.send(
      :get_internal_links, doc, disallow_paths: ['*.php', '*.php[?]*']
    )
  end

  def test_get_internal_links__allow_paths
    url = Wgit::Url.new('http://www.belfastpilates.co.uk/')
    html = File.read('test/mock/fixtures/www.belfastpilates.co.uk/index.html')
    doc = Wgit::Document.new(url, html)
    crawler = Wgit::Crawler.new

    assert_equal [
      'http://www.belfastpilates.co.uk/privacy-policy',
      'http://www.belfastpilates.co.uk/pilates/what-is-pilates',
      'http://www.belfastpilates.co.uk/pilates/pilates-classes',
      'http://www.belfastpilates.co.uk/pilates/pilates-classes/pilates-classes-timetable',
      'http://www.belfastpilates.co.uk/pilates/pilates-faqs',
      'http://www.belfastpilates.co.uk/contact-us'
    ], crawler.send(:get_internal_links, doc, allow_paths: [
      'contact?us',
      'pilates*',
      'privacy-policy'
    ])
  end

  def test_get_internal_links__allow_path
    url = Wgit::Url.new('http://www.belfastpilates.co.uk/')
    html = File.read('test/mock/fixtures/www.belfastpilates.co.uk/index.html')
    doc = Wgit::Document.new(url, html)
    crawler = Wgit::Crawler.new

    assert_equal [
      'http://www.belfastpilates.co.uk/pilates/pilates-classes',
      'http://www.belfastpilates.co.uk/pilates/pilates-classes/pilates-classes-timetable'
    ], crawler.send(:get_internal_links, doc, allow_paths: '*/pilates-classes*')
  end

  def test_get_internal_links__disallow_paths
    url = Wgit::Url.new('http://www.belfastpilates.co.uk/')
    html = File.read('test/mock/fixtures/www.belfastpilates.co.uk/index.html')
    doc = Wgit::Document.new(url, html)
    crawler = Wgit::Crawler.new

    assert_equal [
      'http://www.belfastpilates.co.uk/',
      'http://www.belfastpilates.co.uk/about-us',
      'http://www.belfastpilates.co.uk/about-us/the-team',
      'http://www.belfastpilates.co.uk/about-us/our-facilities',
      'http://www.belfastpilates.co.uk/about-us/testimonials',
      'http://www.belfastpilates.co.uk/physiotheraphy',
      'http://www.belfastpilates.co.uk/latest-news',
      'http://www.belfastpilates.co.uk/official-launch-party',
      'http://www.belfastpilates.co.uk/author/adminbpp',
      'http://www.belfastpilates.co.uk/category/uncategorized',
      'http://www.belfastpilates.co.uk/youre-invited',
      'http://www.belfastpilates.co.uk/gift-vouchers-now-available-to-purchase'
    ], crawler.send(:get_internal_links, doc, disallow_paths: [
      'contact?us',
      'pilates*',
      'privacy-policy'
    ])
  end

  def test_get_internal_links__disallow_path
    url = Wgit::Url.new('http://www.belfastpilates.co.uk/')
    html = File.read('test/mock/fixtures/www.belfastpilates.co.uk/index.html')
    doc = Wgit::Document.new(url, html)
    crawler = Wgit::Crawler.new

    assert_equal [
      'http://www.belfastpilates.co.uk/',
      'http://www.belfastpilates.co.uk/about-us',
      'http://www.belfastpilates.co.uk/about-us/the-team',
      'http://www.belfastpilates.co.uk/about-us/our-facilities',
      'http://www.belfastpilates.co.uk/about-us/testimonials',
      'http://www.belfastpilates.co.uk/privacy-policy',
      'http://www.belfastpilates.co.uk/pilates/what-is-pilates',
      'http://www.belfastpilates.co.uk/pilates/pilates-faqs',
      'http://www.belfastpilates.co.uk/physiotheraphy',
      'http://www.belfastpilates.co.uk/latest-news',
      'http://www.belfastpilates.co.uk/contact-us',
      'http://www.belfastpilates.co.uk/official-launch-party',
      'http://www.belfastpilates.co.uk/author/adminbpp',
      'http://www.belfastpilates.co.uk/category/uncategorized',
      'http://www.belfastpilates.co.uk/youre-invited',
      'http://www.belfastpilates.co.uk/gift-vouchers-now-available-to-purchase'
    ], crawler.send(:get_internal_links, doc, disallow_paths: '*/pilates-classes*')
  end

  def test_get_internal_links__combined_paths
    url = Wgit::Url.new('http://www.belfastpilates.co.uk/')
    html = File.read('test/mock/fixtures/www.belfastpilates.co.uk/index.html')
    doc = Wgit::Document.new(url, html)
    crawler = Wgit::Crawler.new

    assert_equal [
      'http://www.belfastpilates.co.uk/',
      'http://www.belfastpilates.co.uk/about-us/the-team',
      'http://www.belfastpilates.co.uk/about-us/our-facilities',
      'http://www.belfastpilates.co.uk/about-us/testimonials',
      'http://www.belfastpilates.co.uk/pilates/what-is-pilates'
    ], crawler.send(:get_internal_links, doc, disallow_paths: '*/pilates*', allow_paths: [
      'about-us/*',
      'pilates/*',
      '/'
    ])
  end

  private

  def assert_crawl(doc)
    assert doc
    assert_instance_of Wgit::Document, doc
    assert_instance_of Wgit::Url, doc.url
    refute doc.empty?
    assert doc.url.crawled
    refute_nil doc.url.date_crawled
    refute_nil doc.url.crawl_duration
  end

  def assert_crawl_site(
    crawler, url,
    expected_num_crawled, expected_num_externals,
    expected_pages: nil, expected_externals: nil,
    allow_paths: nil, disallow_paths: nil
  )
    crawled = []

    ext_links = crawler.crawl_site(
      url, allow_paths: allow_paths, disallow_paths: disallow_paths
    ) do |doc|
      assert_equal url.to_host, doc.url.to_host
      assert doc.url.crawled?
      refute_nil doc.url.date_crawled

      case doc.url
      when 'http://test-site.com/sneaky' # Redirects to different domain.
        assert_empty doc
        refute_nil doc.url.crawl_duration
      when 'http://test-site.com/ftp'    # Redirects to different host.
        assert_empty doc
        refute_nil doc.url.crawl_duration
      else
        refute_empty doc
        refute_nil doc.url.crawl_duration

        crawled << doc.url
      end
    end

    assert_equal expected_num_crawled, crawled.length
    assert_equal expected_pages, crawled if expected_pages
    assert_equal expected_num_externals, ext_links.length
    assert_equal expected_externals, ext_links if expected_externals
    assert_nil ext_links.uniq!
    assert url.crawled?
    refute_nil url.date_crawled
    refute_nil url.crawl_duration
  end

  def assert_resolve(crawler, start_url, end_url, follow_redirects: true)
    response = Wgit::Response.new
    crawler.send :resolve, start_url, response, follow_redirects: follow_redirects

    assert response.ok?
    assert response.total_time > 0.0
    refute_nil response.body_or_nil
    refute_nil response.ip_address
    assert_equal end_url, response.url
    assert_equal end_url, start_url
    assert_instance_of Typhoeus::Response, response.adapter_response
  end
end
