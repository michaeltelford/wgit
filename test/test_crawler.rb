require "minitest/autorun"
require_relative "helpers/test_helper"
require_relative "../lib/pinch/url"
require_relative "../lib/pinch/crawler"

# @author Michael Telford
class TestCrawler < Minitest::Test
    include TestHelper
    
    def setup
        # Runs before every test.
        @url_str = [
            "https://www.google.co.uk",
            "https://duckduckgo.com",
            "http://www.bing.com"
        ]
        @urls = @url_str.map { |s| Url.new(s) }
    end
    
    def test_initialise
        c = Crawler.new
        assert_empty c.docs
        assert_empty c.urls
        
        c = Crawler.new(*@url_str)
        assert_empty c.docs
        assert_urls c        
        
        c = Crawler.new(*@urls)
        assert_empty c.docs
        assert_urls c
    end
    
    def test_urls=
        c = Crawler.new
        c.urls = @urls
        assert_urls c
        
        c.urls = @url_str
        assert_urls c
        
        c.urls = "https://duckduckgo.com"
        assert_equal ["https://duckduckgo.com"], c.urls
    end
    
    def test_square_brackets
        c = Crawler.new
        c[*@urls]
        assert_urls c
        
        c[*@url_str]
        assert_urls c
    end
    
    def test_double_chevron
        c = Crawler.new
        c << @urls.first
        assert_urls c, @urls.first(1)
        
        c.urls.clear
        c << @url_str.first
        assert_urls c, @url_str.first(1)
    end
    
    def test_crawl_urls
        c = Crawler.new
        i = 0
        urls = @urls.dup
        document = c.crawl_urls urls do |doc|
            assert_crawl_output c, doc, urls[i]
            i += 1
        end
        assert_crawl_output c, document, urls.last
        
        urls = @urls.dup
        c = Crawler.new(*urls)
        i = 0
        document = c.crawl_urls do |doc|
            assert_crawl_output c, doc, c.urls[i]
            i += 1
        end
        assert_crawl_output c, document, urls.last
        
        c = Crawler.new
        url = @urls.dup.first
        document = c.crawl_urls url do |doc|
            assert_crawl_output c, doc, url
        end
        assert_crawl_output c, document, url
        
        c = Crawler.new
        url = Url.new("doesnt_exist")
        document = c.crawl_urls url do |doc|
            assert doc.empty?
            assert url.crawled
        end
        assert_nil document
    end
    
    def test_crawl_url
        c = Crawler.new
        url = @urls.first.dup
        assert_crawl c, url
        
        c = Crawler.new(*@urls.dup)
        assert_crawl c
        
        url = Url.new("doesnt_exist")
        doc = c.crawl_url url
        assert_nil doc
        assert url.crawled
        
        # Test String instead of Url instance.
        url = "http://www.bing.com"
        assert_raises RuntimeError do
            c.crawl_url url
        end
    end
    
    def test_crawl_site
      # Test largish site.
      url = Url.new "http://www.belfastpilates.co.uk"
      c = Crawler.new url
      assert_crawl_site c
      
      # Test small site with externals only on the index page.
      url = Url.new "http://darrenbor.land"
      c = Crawler.new url
      assert_crawl_site c
      
      # Test that an invalid url returns nil.
      url = Url.new "http://doesntexist_123"
      c = Crawler.new url
      assert_nil c.crawl_site
    end
    
    private
    
    def assert_urls(crawler, urls = @urls)
        assert crawler.urls.all? { |url| url.instance_of?(Url) }
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
    
    def assert_crawl_site(crawler)
      ext_links = crawler.crawl_site do |doc|
          refute doc.empty?
          assert doc.url.start_with?(crawler.urls.first.to_base)
          assert doc.url.crawled?
      end
      refute_empty ext_links
      assert_equal ext_links.uniq.length, ext_links.length
      assert crawler.urls.first.crawled?
    end
    
    def assert_crawl_output(crawler, doc, url = nil)
        assert doc
        refute doc.empty?
        url = crawler.urls.first if url.nil?
        assert url.crawled if url
    end
end
