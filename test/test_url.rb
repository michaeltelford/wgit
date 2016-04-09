require "minitest/autorun"
require_relative "test_helper"
require_relative "../lib/pinch/url"

# @author Michael Telford
class TestUrl < Minitest::Test
    include TestHelper
    
    def setup
        # Runs before every test.
        @url_str = "http://www.google.co.uk"
        @bad_url_str = "my_server"
        @link = "/about.html"
        @url_str_link = "#{@url_str}#{@link}"
        @time_stamp = Time.new
        @mongo_doc_dup = { 
            :url => @url_str, 
            :crawled => true, 
            :date_crawled => @time_stamp 
        }
    end
    
    def test_initialize
        url = Url.new @url_str
        assert_equal @url_str, url
        refute url.crawled
        assert_nil url.date_crawled
    end
    
    def test_initialize_from_mongo_doc
        url = Url.new @mongo_doc_dup
        assert_equal @url_str, url
        assert url.crawled
        assert_equal @time_stamp, url.date_crawled
    end
    
    def test_validate
        Url.validate @url_str
        assert_raises(RuntimeError) { Url.validate @bad_url_str }
    end
    
    def test_valid?
        assert Url.valid? @url_str
        refute Url.valid? @bad_url_str
    end
    
    def test_prefix_protocol
        assert_equal "https://#{@bad_url_str}", Url.prefix_protocol(
                                                    @bad_url_str.dup, true)
        assert_equal "http://#{@bad_url_str}", Url.prefix_protocol(
                                                    @bad_url_str.dup)
    end
    
    def test_relative_link?
        assert Url.relative_link? @link
        refute Url.relative_link? @url_str
    end
    
    def test_concat
        assert_equal @url_str_link, Url.concat(@url_str, @link)
        assert_equal @url_str_link, Url.concat(@url_str, @link[1..-1])
    end
    
    def test_crawled=
        url = Url.new @url_str
        url.crawled = true
        assert url.crawled
    end
    
    def test_to_uri
        assert_equal URI::HTTP, Url.new(@url_str).to_uri.class
    end
    
    def test_to_host
        assert_equal "www.google.co.uk", Url.new(@url_str_link).to_host
    end
    
    def test_to_base
        assert_raises(RuntimeError) { Url.new(@link).to_base }
        assert_equal @url_str, Url.new(@url_str_link).to_base
    end
    
    def test_to_h
        assert_equal @mongo_doc_dup, Url.new(@mongo_doc_dup).to_h
    end
end
