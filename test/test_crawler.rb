require_relative "helpers/test_helper"

# Test class for the Crawler methods.
class TestCrawler < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup
    @url_strs = [
      "https://www.google.co.uk",
      "https://duckduckgo.com",
      "http://www.bing.com"
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

    c.urls = "https://duckduckgo.com"
    assert_urls c, [Wgit::Url.new("https://duckduckgo.com")]

    c.urls = Wgit::Url.new "https://duckduckgo.com"
    assert_urls c, [Wgit::Url.new("https://duckduckgo.com")]
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
    url = Wgit::Url.new("doesnt_exist")
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
    c = Wgit::Crawler.new
    url = @urls.first.dup
    assert_crawl c, url

    c = Wgit::Crawler.new(*@urls.dup)
    assert_crawl c

    url = Wgit::Url.new("doesnt_exist")
    doc = c.crawl_url url
    assert_nil doc
    assert_nil c.last_response
    assert url.crawled

    # Test String instead of Url instance.
    url = "http://www.bing.com"
    assert_raises RuntimeError do
      c.crawl_url url
    end
  end

  def test_crawl_site
    # Test largish site - Wordpress site with disgusting HTML.
    url = Wgit::Url.new "http://www.belfastpilates.co.uk/"
    c = Wgit::Crawler.new url
    assert_crawl_site c, 19, 10

    # Test small site - Static well formed HTML.
    url = Wgit::Url.new "http://txti.es"
    c = Wgit::Crawler.new url
    assert_crawl_site c, 7, 8

    # Test single web page with an external link.
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"
    c = Wgit::Crawler.new url
    assert_crawl_site c, 1, 1

    # Test custom small site.
    url = Wgit::Url.new "http://test-site.com"
    c = Wgit::Crawler.new url
    assert_crawl_site c, 4, 0

    # Test custom small site not starting on the index page.
    url = Wgit::Url.new "http://test-site.com/search"
    c = Wgit::Crawler.new url
    assert_crawl_site c, 4, 0

    # Test that an invalid url returns nil.
    url = Wgit::Url.new "http://doesntexist_123"
    c = Wgit::Crawler.new url
    assert_nil c.crawl_site
  end

  def test_resolve__absolute_location
    c = Wgit::Crawler.new
    url = "http://twitter.com/" # Redirects once to https.

    assert_resolve c, url
  end

  def test_resolve__relative_location
    c = Wgit::Crawler.new
    # Redirects twice to /de/folder/page2#anchor-on-page2 on host: example.com
    url = "https://cms.org"

    assert_resolve c, url
  end

  def test_resolve__redirect_limit
    c = Wgit::Crawler.new

    # Redirects 5 times - should resolve.
    url = "http://redirect.com/2"
    assert_resolve c, url

    # Redirects 6 times - should fail.
    url = "http://redirect.com/1"
    assert_raises(RuntimeError) { c.send :resolve, url }

    # Disable redirects - should fail.
    url = 'http://twitter.com/'
    assert_raises RuntimeError do
      c.send :resolve, url, redirect_limit: 0
    end

    # Disable redirects - should pass as there's no redirect.
    url = "https://twitter.com/"
    c.send :resolve, url, redirect_limit: 0

    # Test changing the default limit - should fail, too many redirects.
    Wgit::Crawler.default_redirect_limit = 3
    url = "http://redirect.com/2" # Would pass normally.
    assert_raises(RuntimeError) { c.send :resolve, url }
    Wgit::Crawler.default_redirect_limit = 5 # Back to the original default.
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

  def assert_crawl_site(crawler, expected_num_crawled, expected_num_externals)
    num_crawled = 0
    ext_links = crawler.crawl_site do |doc|
      # byebug if doc.empty? # Leave commented out as it's a useful debugger.
      doc.url == 'http://test-site.com/sneaky' ? assert_empty(doc) : refute_empty(doc)
      assert doc.url.start_with?(crawler.urls.first.to_base)
      assert doc.url.crawled?
      num_crawled += 1
    end

    assert_equal expected_num_crawled, num_crawled
    assert_equal expected_num_externals, ext_links.length
    assert_equal ext_links.uniq.length, ext_links.length
    assert crawler.urls.first.crawled?
  end

  def assert_crawl_output(crawler, doc, url = nil)
    assert crawler.last_response.is_a? Net::HTTPResponse
    assert doc
    refute doc.empty?
    url = crawler.urls.first if url.nil?
    assert url.crawled if url
  end

  def assert_resolve(crawler, url)
    response = crawler.send :resolve, url
    assert response.is_a? Net::HTTPResponse
    assert_equal "200", response.code
    refute response.body.empty?
  end
end
