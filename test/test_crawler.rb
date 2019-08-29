require_relative 'helpers/test_helper'

# Test class for the Crawler methods.
class TestCrawler < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup
    @url_strs = [
      'https://www.google.co.uk',
      'https://duckduckgo.com',
      'http://www.bing.com'
    ]
    @urls = @url_strs.map { |s| Wgit::Url.new(s) }
  end

  def test_initialise
    c = Wgit::Crawler.new
    assert_empty c.docs
    assert_empty c.urls
    assert_nil c.last_response

    c = Wgit::Crawler.new(*@url_strs)
    assert_empty c.docs
    assert_urls c
    assert_nil c.last_response

    c = Wgit::Crawler.new(*@urls)
    assert_empty c.docs
    assert_urls c
    assert_nil c.last_response

    c = Wgit::Crawler.new(@urls)
    assert_empty c.docs
    assert_urls c
    assert_nil c.last_response
  end

  def test_urls=
    c = Wgit::Crawler.new
    c.urls = @urls
    assert_urls c

    c.urls = @url_strs
    assert_urls c

    c.urls = 'https://duckduckgo.com'
    assert_urls c, [Wgit::Url.new('https://duckduckgo.com')]

    c.urls = Wgit::Url.new 'https://duckduckgo.com'
    assert_urls c, [Wgit::Url.new('https://duckduckgo.com')]
  end

  def test_square_brackets
    c = Wgit::Crawler.new
    c[*@urls]
    assert_urls c

    c[@urls]
    assert_urls c

    c[*@url_strs]
    assert_urls c
  end

  def test_double_chevron
    c = Wgit::Crawler.new
    c << @urls.first
    assert_urls c, @urls.first(1)

    c.urls.clear
    c << @url_strs.first
    assert_urls c, @url_strs.first(1)
  end

  def test_crawl_urls
    c = Wgit::Crawler.new
    i = 0

    # Test array of urls as parameter.
    urls = @urls.dup
    document = c.crawl_urls urls do |doc|
      assert_crawl_output c, doc, urls[i]
      i += 1
    end
    assert_crawl_output c, document, urls.last

    # Test array of urls as instance var.
    urls = @urls.dup
    c = Wgit::Crawler.new(*urls)
    i = 0
    document = c.crawl_urls do |doc|
      assert_crawl_output c, doc, c.urls[i]
      i += 1
    end
    assert_crawl_output c, document, urls.last

    # Test one url as parameter.
    c = Wgit::Crawler.new
    url = @urls.dup.first
    document = c.crawl_urls url do |doc|
      assert_crawl_output c, doc, url
    end
    assert_crawl_output c, document, url

    # Test invalid url.
    c = Wgit::Crawler.new
    url = Wgit::Url.new('doesnt_exist')
    document = c.crawl_urls url do |doc|
      assert doc.empty?
      assert url.crawled
    end
    assert_nil document

    # Test no block given.
    urls = @urls.dup
    document = c.crawl_urls urls
    assert_crawl_output c, document, urls.last
    assert_equal urls.length, c.docs.length
    assert_equal urls, c.docs.map(&:url)
  end

  def test_crawl_url
    # Valid URL passed to method.
    c = Wgit::Crawler.new
    url = @urls.first.dup
    assert_crawl c, url

    # Valid URL passed to constructor.
    c = Wgit::Crawler.new(*@urls.dup)
    assert_crawl c

    # Invalid URL.
    url = Wgit::Url.new('doesnt_exist')
    document = c.crawl_url(url) do |doc|
      assert_equal url, doc.url
      assert_empty doc
    end
    assert_nil document
    assert_nil c.last_response
    assert url.crawled

    # Non ASCII chars in the URL.
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'https://www.über.com/about'
    assert_crawl c, url
    assert_equal 'https://www.über.com/about', url

    # String instead of Url instance.
    url = 'http://www.bing.com'
    ex = assert_raises(RuntimeError) { c.crawl_url url }
    assert_equal 'Expected: Wgit::Url, Actual: String', ex.message
  end

  def test_crawl_url__redirects
    # Url redirect passed to crawler doesn't update.
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    c = Wgit::Crawler.new url
    c.crawl_url do |doc|
      assert_equal 'https://motherfuckingwebsite.com/', doc.url
      refute_empty doc
    end
    assert_equal 'http://test-site.com/sneaky', url

    # Url redirect passed to method does update.
    c = Wgit::Crawler.new
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    c.crawl_url(url) do |doc|
      assert_equal 'https://motherfuckingwebsite.com/', doc.url
      refute_empty doc
    end
    assert_equal 'https://motherfuckingwebsite.com/', url

    # Url redirect not affected by random domain.
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    c.crawl_url(url, domain: url.to_base) do |doc|
      assert_equal 'https://motherfuckingwebsite.com/', doc.url
      refute_empty doc
    end
    assert_equal 'https://motherfuckingwebsite.com/', url

    # Url redirect not allowed.
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    c.crawl_url(
      url,
      follow_external_redirects: false,
      domain: url.to_base
    ) do |doc|
      assert_equal 'http://test-site.com/sneaky', doc.url
      assert_empty doc
    end
    assert_equal 'http://test-site.com/sneaky', url

    # Url redirect parameter error.
    url = Wgit::Url.new 'http://test-site.com/sneaky'
    ex = assert_raises(RuntimeError) do
      c.crawl_url(url, follow_external_redirects: false)
    end
    assert_equal 'http://test-site.com/sneaky', url
    assert_equal 'domain cannot be nil if follow_external_redirects is false', ex.message
  end

  def test_crawl_site
    # Test largish site - Wordpress site with disgusting HTML.
    url = Wgit::Url.new 'http://www.belfastpilates.co.uk/'
    c = Wgit::Crawler.new url
    assert_crawl_site c, 19, 10, expected_pages: [
      "http://www.belfastpilates.co.uk/",
      "http://www.belfastpilates.co.uk/about-us",
      "http://www.belfastpilates.co.uk/about-us/the-team",
      "http://www.belfastpilates.co.uk/about-us/our-facilities",
      "http://www.belfastpilates.co.uk/about-us/testimonials",
      "http://www.belfastpilates.co.uk/privacy-policy",
      "http://www.belfastpilates.co.uk/pilates/what-is-pilates",
      "http://www.belfastpilates.co.uk/pilates/pilates-classes",
      "http://www.belfastpilates.co.uk/pilates/pilates-classes/pilates-classes-timetable",
      "http://www.belfastpilates.co.uk/pilates/pilates-faqs",
      "http://www.belfastpilates.co.uk/physiotheraphy",
      "http://www.belfastpilates.co.uk/latest-news",
      "http://www.belfastpilates.co.uk/contact-us",
      "http://www.belfastpilates.co.uk/official-launch-party",
      "http://www.belfastpilates.co.uk/author/adminbpp",
      "http://www.belfastpilates.co.uk/category/uncategorized",
      "http://www.belfastpilates.co.uk/youre-invited",
      "http://www.belfastpilates.co.uk/gift-vouchers-now-available-to-purchase",
      "http://www.belfastpilates.co.uk/pilates",
    ]

    # Test small site - Static well formed HTML.
    url = Wgit::Url.new 'http://txti.es'
    c = Wgit::Crawler.new url
    assert_crawl_site c, 7, 8, expected_pages: [
      "http://txti.es",
      "http://txti.es/about",
      "http://txti.es/how",
      "http://txti.es/terms",
      "http://txti.es/images",
      "http://txti.es/barry/json",
      "http://txti.es/images/images"
    ]

    # Test single web page with a single external link.
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    c = Wgit::Crawler.new url
    assert_crawl_site c, 1, 1, expected_pages: [
      'https://motherfuckingwebsite.com/',
    ], expected_externals: [
      'http://txti.es'
    ]

    # Test custom small site.
    url = Wgit::Url.new 'http://test-site.com'
    c = Wgit::Crawler.new url
    assert_crawl_site c, 6, 2, expected_pages: [
      'http://test-site.com',
      'http://test-site.com/contact',
      'http://test-site.com/search',
      'http://test-site.com/about',
      'http://test-site.com/public/records',
      'http://test-site.com/public/records?q=username',
    ], expected_externals: [
      "http://test-site.co.uk",
      "http://ftp.test-site.com",
    ]

    # Test custom small site not starting on the index page.
    url = Wgit::Url.new 'http://test-site.com/search'
    c = Wgit::Crawler.new url
    assert_crawl_site c, 6, 2, expected_pages: [
      'http://test-site.com/search',
      'http://test-site.com/',
      'http://test-site.com/contact',
      'http://test-site.com/about',
      'http://test-site.com/public/records',
      'http://test-site.com/public/records?q=username',
    ], expected_externals: [
      "http://test-site.co.uk",
      "http://ftp.test-site.com",
    ]

    # Test that an invalid url returns nil.
    url = Wgit::Url.new 'http://doesntexist_123'
    c = Wgit::Crawler.new url
    assert_nil c.crawl_site
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
    ex = assert_raises(RuntimeError) { c.send :resolve, url }
    assert_equal 'Too many redirects', ex.message
    assert_equal 'http://redirect.com/6', url

    # Disable redirects - should fail.
    url = Wgit::Url.new 'http://twitter.com/'
    ex = assert_raises(RuntimeError) { c.send :resolve, url, redirect_limit: 0 }
    assert_equal 'Too many redirects', ex.message
    assert_equal 'http://twitter.com/', url

    # Disable redirects - should pass as there's no redirect.
    url = Wgit::Url.new 'https://twitter.com/'
    c.send :resolve, url, redirect_limit: 0
    assert_equal 'https://twitter.com/', url

    # Test changing the default limit - should fail, too many redirects.
    Wgit::Crawler.default_redirect_limit = 3

    url = Wgit::Url.new 'http://redirect.com/2' # Would pass normally.
    ex = assert_raises(RuntimeError) { c.send :resolve, url }
    assert_equal 'Too many redirects', ex.message
    assert_equal 'http://redirect.com/5', url

    Wgit::Crawler.default_redirect_limit = 5 # Back to the original default.
  end

  def test_resolve__uri_error
    c = Wgit::Crawler.new
    url = 'http://redirect.com/1'

    ex = assert_raises(RuntimeError) { c.send :resolve, url }
    assert_equal 'url must respond to :to_uri', ex.message
    assert_equal 'http://redirect.com/1', url
  end

  def test_resolve__redirect_not_allowed
    c = Wgit::Crawler.new
    url = 'http://twitter.com'.to_url

    ex = assert_raises(RuntimeError) do
      c.send(
        :resolve,
        url,
        follow_external_redirects: false,
        domain: 'http://twitter.co.uk'
      )
    end
    assert_equal "External redirect not allowed - Redirected to: \
'https://twitter.com', allowed domain: 'http://twitter.co.uk'", ex.message
    assert_equal 'http://twitter.com', url
  end

  def test_resolve__redirect_to_any_external_url_fails
    c = Wgit::Crawler.new
    url = 'http://twitter.com'.to_url

    ex = assert_raises(RuntimeError) do
      # Because domain defaults to nil, any external redirect will fail.
      c.send :resolve, url, follow_external_redirects: false
    end
    assert_equal "External redirect not allowed - Redirected to: \
'https://twitter.com', allowed domain: ''", ex.message
    assert_equal 'http://twitter.com', url
  end

  def test_resolve__redirect_yielded
    i = 0
    c = Wgit::Crawler.new
    orig_url = Wgit::Url.new 'http://redirect.com/5' # Redirects twice to 7.

    resp = c.send(:resolve, orig_url) do |url, response, location|
      i += 1
      path = url.to_path.to_i + 1

      assert_instance_of Wgit::Url, url
      assert_instance_of Wgit::Url, location
      assert response.is_a?(Net::HTTPRedirection) unless location.empty?

      assert_equal orig_url, url if i == 1
      assert_equal path, location.to_path.to_i unless location.empty?
    end
    assert_instance_of Net::HTTPOK, resp
  end

private

  def assert_urls(crawler, urls = @urls)
    assert crawler.urls.all? { |url| url.instance_of?(Wgit::Url) }
    assert_equal urls, crawler.urls
  end

  def assert_crawl(crawler, url = nil)
    if url
      document = crawler.crawl_url(url) { |doc| assert doc.title }
    else
      document = crawler.crawl_url { |doc| assert doc.title }
    end

    assert_crawl_output crawler, document, url
  end

  def assert_crawl_site(crawler, expected_num_crawled, expected_num_externals, expected_pages: nil, expected_externals: nil)
    crawled = []

    ext_links = crawler.crawl_site do |doc|
      assert doc.url.start_with?(crawler.urls.first.to_base)
      assert doc.url.crawled?

      if doc.url == 'http://test-site.com/sneaky'
        assert_empty(doc)
      else
        refute_empty(doc)
        crawled << doc.url
      end
    end

    assert_equal expected_num_crawled, crawled.length
    assert_equal expected_pages, crawled if expected_pages
    assert_equal expected_num_externals, ext_links.length
    assert_equal expected_externals, ext_links if expected_externals
    assert_nil ext_links.uniq!
    assert crawler.urls.first.crawled?
  end

  def assert_crawl_output(crawler, doc, url = nil)
    assert crawler.last_response.is_a? Net::HTTPResponse
    assert doc
    refute doc.empty?

    url = crawler.urls.first if url.nil?
    assert url.crawled if url
  end

  def assert_resolve(crawler, start_url, end_url)
    response = crawler.send :resolve, start_url

    assert response.is_a? Net::HTTPResponse
    assert_equal '200', response.code
    refute response.body.empty?
    assert_equal end_url, start_url
  end
end
