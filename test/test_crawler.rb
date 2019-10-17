require_relative 'helpers/test_helper'

# Crawl the site by it's <a> tags that link to jpg's.
class ImageCrawler < Wgit::Crawler
  def get_internal_links(doc)
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
  end

  def test_initialise__redirect_limit
    c = Wgit::Crawler.new redirect_limit: 3

    assert_nil c.last_response
    assert_equal 3, c.redirect_limit
    assert_equal 5, c.time_out
  end

  def test_initialise__time_out
    c = Wgit::Crawler.new time_out: 3

    assert_nil c.last_response
    assert_equal 5, c.redirect_limit
    assert_equal 3, c.time_out
  end

  def test_crawl_url
    # Valid Url.
    c = Wgit::Crawler.new
    url = 'https://duckduckgo.com'.to_url
    doc = c.crawl_url(url) { |d| assert_crawl(d) }
    assert_equal 200, c.last_response.code
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
    assert_nil c.last_response
    assert_equal 'doesnt_exist', url
    assert url.crawled
    refute_nil url.date_crawled
    assert_nil url.crawl_duration

    # IRI (non ASCII) Url.
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'https://www.über.com/about'
    doc = c.crawl_url(url) { |d| assert_crawl(d) }
    assert_equal 200, c.last_response.code
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

    assert_equal 200, crawler.last_response.code
    assert_equal 'https://vlang.io/', url
    assert_equal url, doc.url
    assert_crawl doc
    assert url.crawled
    refute_nil url.date_crawled
    refute_nil url.crawl_duration
  end

  def test_crawl_url__redirects
    # Url passed to method updates on redirect.
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    c.crawl_url(url) do |doc|
      assert_equal 'https://motherfuckingwebsite.com/', doc.url
      refute_empty doc
    end
    assert_equal 'https://motherfuckingwebsite.com/', url

    # Url redirect not affected by host: X if follow_external_redirects: true.
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    c.crawl_url(url, host: url.to_base) do |doc|
      assert_equal 'https://motherfuckingwebsite.com/', doc.url
      refute_empty doc
    end
    assert_equal 'https://motherfuckingwebsite.com/', url

    # Url redirect not allowed.
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    c.crawl_url(
      url,
      follow_external_redirects: false,
      host: url.to_base
    ) do |doc|
      assert_equal 'http://test-site.com/sneaky', doc.url
      assert_empty doc
    end
    assert_equal 'http://test-site.com/sneaky', url

    # Url redirect parameter error.
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    e = assert_raises(StandardError) do
      c.crawl_url(url, follow_external_redirects: false)
    end
    assert_equal 'http://test-site.com/sneaky', url
    assert_equal 'host cannot be nil if follow_external_redirects is false', e.message
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
      assert_equal 200, c.last_response.code
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
      assert_equal 200, c.last_response.code
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
      assert_nil c.last_response
      assert d.empty?
      assert d.url.crawled
    end
    assert_nil doc
    assert url.crawled
    refute_nil url.date_crawled
    assert_nil url.crawl_duration

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
        assert_nil c.last_response
        assert_empty d
      else
        assert_equal 200, c.last_response.code
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
    assert_equal 200, crawler.last_response.code

    refute_empty externals
    assert externals.all? { |url| url.instance_of? Wgit::Url }
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
    crawler = ImageCrawler.new
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
    response = c.send :fetch, url

    assert_equal 0, c.last_response.redirect_count
    assert c.last_response.total_time > 0.0
    refute_nil response
    assert url.crawled
    refute_nil url.date_crawled
    refute_nil url.crawl_duration
  end

  def test_fetch__invalid_url
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'doesnt_exist'
    response = c.send :fetch, url

    assert_nil response
    assert url.crawled
    refute_nil url.date_crawled
    assert_nil url.crawl_duration
  end

  def test_resolve__absolute_location
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'http://twitter.com/' # Redirects once to https.

    assert_resolve c, url, 'https://twitter.com'
  end

  def test_resolve__relative_location
    c = Wgit::Crawler.new
    # Redirects twice to https://example.com/de/folder/page2#anchor-on-page2
    url = Wgit::Url.new 'https://cms.org'

    assert_resolve c, url, 'https://example.com/de/folder/page2#anchor-on-page2'
  end

  def test_resolve__redirect_limit
    c = Wgit::Crawler.new

    # Redirects 5 times - should resolve.
    url = Wgit::Url.new 'http://redirect.com/2'
    assert_resolve c, url, 'http://redirect.com/7'

    # Redirects 6 times - should fail.
    url = Wgit::Url.new 'http://redirect.com/1'
    e = assert_raises(StandardError) { c.send :resolve, url }
    assert_equal 'Too many redirects, exceeded: 5', e.message
    assert_equal 'http://redirect.com/6', url

    c = Wgit::Crawler.new redirect_limit: 0

    # Disable redirects - should fail for too many redirects.
    url = Wgit::Url.new 'http://twitter.com/'
    e = assert_raises(StandardError) { c.send :resolve, url }
    assert_equal 'Too many redirects, exceeded: 0', e.message
    assert_equal 'http://twitter.com/', url

    # Disable redirects - should pass as there's no redirect.
    url = Wgit::Url.new 'https://twitter.com/'
    c.send :resolve, url
    assert_equal 'https://twitter.com/', url

    c = Wgit::Crawler.new redirect_limit: 3

    url = Wgit::Url.new 'http://redirect.com/2' # Would pass normally.
    e = assert_raises(StandardError) { c.send :resolve, url }
    assert_equal 'Too many redirects, exceeded: 3', e.message
    assert_equal 'http://redirect.com/5', url
  end

  def test_resolve__time_out
    # Unrealistically short time out causes an error.
    c = Wgit::Crawler.new time_out: 0.001

    url = Wgit::Url.new 'http://doesnt_exist/' # Mocks a time out.
    e = assert_raises(StandardError) { c.send :resolve, url }
    assert_equal 'No response (within timeout: 0.001 second(s))', e.message

    # Disable time outs.
    c = Wgit::Crawler.new time_out: 0

    url = Wgit::Url.new 'http://test-site.com'
    resp = c.send :resolve, url
    assert_equal 200, resp.code
  end

  def test_resolve__uri_error
    c = Wgit::Crawler.new
    url = 'http://redirect.com/1'

    e = assert_raises(StandardError) { c.send :resolve, url }
    assert_equal 'url must respond to :normalize', e.message
    assert_equal 'http://redirect.com/1', url
  end

  def test_resolve__invalid_url
    c = Wgit::Crawler.new
    url = 'http://doesnt_exist/'.to_url

    e = assert_raises(StandardError) { c.send(:resolve, url) }
    assert_equal 'No response (within timeout: 5 second(s))', e.message
  end

  def test_resolve__redirect_to_any_external_url_works
    c = Wgit::Crawler.new
    # Redirects once to motherfuckingwebsite.com.
    url = Wgit::Url.new 'http://test-site.com/sneaky'

    assert_resolve c, url, 'https://motherfuckingwebsite.com/'
  end

  def test_resolve__redirect_not_allowed
    c = Wgit::Crawler.new
    url = 'http://twitter.com'.to_url

    e = assert_raises(StandardError) do
      c.send(
        :resolve, url,
        follow_external_redirects: false, host: 'http://twitter.co.uk'
      )
    end
    assert_equal "External redirect not allowed - Redirected to: \
'https://twitter.com', which is outside of host: 'http://twitter.co.uk'", e.message
    assert_equal 'http://twitter.com', url
  end

  def test_resolve__redirect_to_any_external_url_fails
    c = Wgit::Crawler.new
    url = 'http://twitter.com'.to_url

    e = assert_raises(StandardError) do
      # Because host defaults to nil, any external redirect will fail.
      c.send :resolve, url, follow_external_redirects: false
    end
    assert_equal "External redirect not allowed - Redirected to: \
'https://twitter.com', which is outside of host: ''", e.message
    assert_equal 'http://twitter.com', url
  end

  def test_resolve__redirect_yielded
    i = 0
    c = Wgit::Crawler.new

    # Redirects twice to 7.
    orig_url = Wgit::Url.new 'http://redirect.com/5'
    resp = c.send(:resolve, orig_url) do |url, response, location|
      i += 1
      path = url.to_path.to_i + 1

      assert_instance_of Wgit::Url, url
      assert_instance_of Wgit::Url, location
      assert_equal 301, response.code unless location.empty?

      assert_equal orig_url, url if i == 1
      assert_equal path, location.to_path.to_i unless location.empty?
    end
    assert_instance_of Typhoeus::Response, resp
    assert_equal 200, resp.code
    assert_equal 2, resp.redirect_count
    assert resp.total_time > 0.0

    # Doesn't redirect.
    orig_url = Wgit::Url.new 'https://twitter.com'
    resp = c.send(:resolve, orig_url) do |url, response, location|
      assert_instance_of Wgit::Url, url
      assert_instance_of Wgit::Url, location
      assert_equal 200, response.code

      assert_equal orig_url, url
      assert_empty location
    end
    assert_instance_of Typhoeus::Response, resp
    assert_equal 200, resp.code
    assert_equal 0, resp.redirect_count
    assert resp.total_time > 0.0
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
  end

  private

  def assert_crawl(doc)
    assert doc
    assert_instance_of Wgit::Document, doc
    assert_instance_of Wgit::Url, doc.url
    refute doc.empty?
    assert doc.url.crawled
    refute_nil doc.date_crawled
    refute_nil doc.crawl_duration
  end

  def assert_crawl_site(
    crawler, url,
    expected_num_crawled, expected_num_externals,
    expected_pages: nil, expected_externals: nil
  )
    crawled = []

    ext_links = crawler.crawl_site(url) do |doc|
      assert_equal url.to_host, doc.url.to_host
      assert doc.url.crawled?
      refute_nil doc.date_crawled

      case doc.url
      when 'http://test-site.com/sneaky' # Redirects to different host.
        assert_empty doc
        assert_nil doc.crawl_duration
      when 'http://test-site.com/ftp'    # Redirects to different host.
        assert_empty doc
        assert_nil doc.crawl_duration
      else
        refute_empty doc
        refute_nil doc.crawl_duration

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

  def assert_resolve(crawler, start_url, end_url)
    response = crawler.send :resolve, start_url

    assert_equal 200, response.code
    assert response.total_time > 0.0
    refute response.body.empty?
    assert_equal end_url, start_url
  end
end
