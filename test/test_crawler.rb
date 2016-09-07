require "minitest/autorun"
require 'minitest/pride'
require_relative "helpers/test_helper"
require_relative "../lib/wgit/url"
require_relative "../lib/wgit/crawler"

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
        @urls = @url_str.map { |s| Wgit::Url.new(s) }
    end
    
    def test_initialise
        c = Wgit::Crawler.new
        assert_empty c.docs
        assert_empty c.urls
        
        c = Wgit::Crawler.new(*@url_str)
        assert_empty c.docs
        assert_urls c        
        
        c = Wgit::Crawler.new(*@urls)
        assert_empty c.docs
        assert_urls c
    end
    
    def test_urls=
        c = Wgit::Crawler.new
        c.urls = @urls
        assert_urls c
        
        c.urls = @url_str
        assert_urls c
        
        c.urls = "https://duckduckgo.com"
        assert_equal ["https://duckduckgo.com"], c.urls
    end
    
    def test_square_brackets
        c = Wgit::Crawler.new
        c[*@urls]
        assert_urls c
        
        c[*@url_str]
        assert_urls c
    end
    
    def test_double_chevron
        c = Wgit::Crawler.new
        c << @urls.first
        assert_urls c, @urls.first(1)
        
        c.urls.clear
        c << @url_str.first
        assert_urls c, @url_str.first(1)
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
        assert_equal urls, c.docs.map { |doc| doc.url }
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
        assert url.crawled
        
        # Test String instead of Url instance.
        url = "http://www.bing.com"
        assert_raises RuntimeError do
            c.crawl_url url
        end
    end
    
    def test_crawl_site
      # Test largish site.
      url = Wgit::Url.new "http://www.belfastpilates.co.uk"
      c = Wgit::Crawler.new url
      assert_crawl_site c
      
      # Test small site with externals only on the index page.
      url = Wgit::Url.new "http://darrenbor.land"
      c = Wgit::Crawler.new url
      assert_crawl_site c
      
      # Test that an invalid url returns nil.
      url = Wgit::Url.new "http://doesntexist_123"
      c = Wgit::Crawler.new url
      assert_nil c.crawl_site
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
