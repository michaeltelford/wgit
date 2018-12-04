require "minitest/autorun"
require 'minitest/pride'
require_relative "helpers/test_helper"
require_relative "../lib/wgit/web_crawler"
require_relative "../lib/wgit/database/database_helper"

# @author Michael Telford
# WARNING: The DB is cleared down prior to each test run.
class TestWebCrawler < Minitest::Test
    include TestHelper
    include Wgit::DatabaseHelper
    
    # Runs before every test.
    def setup
      clear_db
    end
    
    def test_crawl_the_web
      url_str = "https://motherfuckingwebsite.com/"
      seed { url url: url_str, crawled: false }
      
      # Crawl only one site.
      Wgit.crawl_the_web 1
      
      # Assert that crawled gets updated.
      refute url? url: url_str, crawled: false
      assert url? url: url_str, crawled: true
      
      # Assert that some indexed docs where inserted into the DB.
      assert num_records > 2 # the orig url and its doc plus at least 1.
    end
end
