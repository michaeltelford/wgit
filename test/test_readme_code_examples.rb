require "minitest/autorun"
require 'minitest/pride'
require_relative "helpers/test_helper"
require_relative "../lib/wgit/database/mongo_connection_details"

# @author Michael Telford
class TestReadmeCodeExamples < Minitest::Test
    include TestHelper
    
    # Runs before every test.
    def setup
    end
    
    def test_basic_usage
      require 'wgit'

      crawler = Wgit::Crawler.new
      url = Wgit::Url.new "https://wikileaks.org/What-is-Wikileaks.html"

      doc = crawler.crawl url
      doc.stats
      
      assert_equal({
        :url=>44, :html=>28133, :title=>17, :keywords=>0, :links=>35, 
        :text_length=>67, :text_bytes=>13735
      }, doc.stats)

      doc.class
       
      assert_equal Wgit::Document, doc.class
      
      Wgit::Document.instance_methods(false).sort
       
      assert_equal [
        :author, :empty?, :external_links, :external_urls, :html, :internal_full_links, 
        :internal_links, :keywords, :links, :relative_full_links, :relative_full_urls, 
        :relative_links, :relative_urls, :score, :search, :search!, :size, :stats, :text, 
        :title, :to_h, :to_hash, :url, :xpath
      ], Wgit::Document.instance_methods(false).sort

      results = doc.search "corruption"
      results.first
      
      assert_equal(
        "ial materials involving war, spying and corruption. It has so far published more", 
        results.first
      )
    end
    
    def test_css_indexer
      require 'wgit'
      require 'wgit/core_ext'

      crawler = Wgit::Crawler.new
      url = "https://www.facebook.com".to_url

      doc = crawler.crawl url

      # Provide your own xpath to search the HTML using Nokogiri.
      css_urls = doc.xpath "//link[@rel='stylesheet']/@href"

      css_urls.class
      assert_equal Nokogiri::XML::NodeSet, css_url.class
      
      css_url = css_urls.first.value
      assert_equal(
        "https://static.xx.fbcdn.net/rsrc.php/v3/yE/r/uqWZrDdEiFq.css", 
        css_urls.first.value
      )

      css = crawler.crawl css_url.to_url
      css[0..50]
      
      assert_equal ".UIContentTopper{padding:14px 0 0 17px;margin:50px ", css[0..50]
    end
    
    def test_keyword_indexer
      require 'wgit'
      require 'wgit/core_ext'

      my_pages_keywords = ["altitude", "mountaineering", "adventure"]
      my_pages_missing_keywords = []

      competitor_urls = [
      	"http://altitudejunkies.com", 
      	"http://www.mountainmadness.com", 
      	"http://www.adventureconsultants.com"
      ].to_urls

      crawler = Wgit::Crawler.new competitor_urls
      
      # NOTE: We comment out any puts as we don't want to see the output during tests. 

      crawler.crawl do |doc|
      	#puts "The keywords for #{doc.url} are: \n#{doc.keywords}\n\n"
      	refute_empty doc.keywords
      	my_pages_missing_keywords.concat(doc.keywords - my_pages_keywords)
      end

      #puts "Your pages compared to your competitors are missing the following keywords:"
      #puts my_pages_missing_keywords.uniq!
      refute_empty my_pages_missing_keywords.uniq!
      assert_equal([
        "", "", "" ...
      ], my_pages_missing_keywords)
    end
    
    def test_database_example
      require 'wgit'
      require 'wgit/core_ext'

      # Here we create our own document rather than crawl one. 
      doc = Wgit::Document.new(
      	"http://test-url.com".to_url, 
      	"<p>Some text to search for.</p><a href='http://www.google.co.uk'>Click me!</a>"
      )

      # NOTE: We use the required DB connection details instead of replacing them below to 
      # avoid them being accidentally copied into the README.md by mistake. 

      #Wgit::CONNECTION_DETAILS = {
      #  :host           => "<host_machine>",
      #  :port           => "27017", # MongoDB's default port is shown here.
      #  :db             => "<database_name>",
      #  :uname          => "<username>",
      #  :pword          => "<password>"
      #}.freeze

      db = Wgit::Database.new
      db.insert doc

      # Searching the DB returns documents with 'hits'. 
      results = db.search "text"

      # doc == results.first # => Commented out because it causes a warning. 
      assert doc == results.first

      # Searching a document returns text snippets with 'hits' within that document. 
      doc.search("text").first
      assert_equal "Some text to search for.", doc.search("text").first

      db.insert doc.external_links

      urls_to_crawl = db.uncrawled_urls # => Results will include doc.external_links. 
      doc.external_links.each do |link|
        assert urls_to_crawl.include? link
      end
    end
end
