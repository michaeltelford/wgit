require "minitest/autorun"
require "minitest/pride"
require 'securerandom'
require_relative "helpers/test_helper"
require_relative "../lib/wgit/database/mongo_connection_details"
require_relative "../lib/wgit/database/database_helper"

# WARNING: The DB is cleared down at the start of the database example test.
class TestReadmeCodeExamples < Minitest::Test
  include TestHelper
  include Wgit::DatabaseHelper
  
  # Runs before every test.
  def setup
  end
  
  def test_basic_usage
    require 'wgit'

    crawler = Wgit::Crawler.new
    url = Wgit::Url.new "https://wikileaks.org/What-is-Wikileaks.html"

    doc = crawler.crawl url
    doc.stats
    
    # We don't assert the stats because they change as its a wiki. 
    assert_equal Hash, doc.stats.class

    doc.class
      
    assert_equal Wgit::Document, doc.class
    
    Wgit::Document.instance_methods(false).sort
      
    assert_equal [
      :==, :[], :author, :css, :date_crawled, :doc, :empty?, :external_links,
      :external_urls, :html, :internal_full_links, :internal_links, :keywords,
      :links, :relative_full_links, :relative_full_urls, :relative_links,
      :relative_urls, :score, :search, :search!, :size, :stats, :text,
      :title, :to_h, :to_hash, :to_json, :url, :xpath
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
    url = "https://blog.carbonfive.com/".to_url

    doc = crawler.crawl url

    # Provide your own xpath to search the HTML using Nokogiri.
    css_urls = doc.xpath "//link[@rel='stylesheet']/@href"

    css_urls.class
    assert_equal Nokogiri::XML::NodeSet, css_urls.class
    
    css_url = css_urls.first.value
    assert css_url.start_with? "https://blog.carbonfive.com/wp-content/"

    css = crawler.crawl css_url.to_url
    css[0..50]
    
    assert_equal ".jetpack-simple-payments-wrapper {\n\tmargin-bottom: ", css[0..50]
  end
  
  def test_keyword_indexer
    require 'wgit'
    require 'wgit/core_ext'

    my_pages_keywords = ["mountain climbing", "Everest"]
    my_pages_missing_keywords = []

    competitor_urls = [
      "http://altitudejunkies.com", 
      "http://www.mountainmadness.com", 
      "http://www.adventureconsultants.com"
    ].to_urls

    crawler = Wgit::Crawler.new(*competitor_urls)
    
    # NOTE: We comment out any puts as we don't want to see the output during tests. 

    crawler.crawl do |doc|
      if doc.keywords.respond_to? :-
        #puts "The keywords for #{doc.url} are: \n#{doc.keywords}\n\n"
        my_pages_missing_keywords.concat(doc.keywords - my_pages_keywords)
      end
    end

    #puts "Your pages compared to your competitors are missing the following keywords:"
    #puts my_pages_missing_keywords.uniq!
    my_pages_missing_keywords.uniq!
    
    refute_empty my_pages_missing_keywords
    assert_equal([
      "mountaineering school", "seven summits", 
      "Kilimanjaro", "climb", "trekking", "mountain madness"
    ], my_pages_missing_keywords)
  end
  
  def test_database_example
    require 'wgit'
    require 'wgit/core_ext'
    require 'securerandom'
    
    clear_db

    # Here we create our own document rather than crawl one. 
    doc = Wgit::Document.new(
      "http://test-url.com/#{SecureRandom.uuid}".to_url, 
      "<p>Some text to search for.</p><a href='http://www.google.co.uk'>Click me!</a>"
    )

    # NOTE: We use the required DB connection details instead of replacing them below to 
    # avoid them being accidentally copied into the README.md by mistake. 

    #Wgit::CONNECTION_DETAILS = {
    #  host : "<host_machine>",
    #  port : "27017", # MongoDB's default port is shown here.
    #  db   : "<database_name>",
    #  uname: "<username>",
    #  pword: "<password>"
    #}.freeze

    db = Wgit::Database.new
    db.insert doc

    # Searching the DB returns documents with 'hits'. 
    results = db.search "text"

    # doc == results.first # => Commented out because it causes a warning. 
    assert doc.url == results.first.url

    # Searching a document returns text snippets with 'hits' within that document. 
    doc.search("text").first
    assert_equal "Some text to search for.", doc.search("text").first

    db.insert doc.external_links

    urls_to_crawl = db.uncrawled_urls # => Results will include doc.external_links. 
    
    doc.external_links.each do |link|
      assert urls_to_crawl.include? link
    end
  end
  
  def test_extending_the_api_text_elements
    # Let's add the text of links e.g. <a> tags.
    Wgit::Document.text_elements << :a

    # Our Document has a link whose's text we're interested in.
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p>\
    <a href='https://made-up-link.com'>Click this link.</a></html>"
    )

    # Now all crawled Documents will contain all link text in Document#text.
    # doc.text # => ["Hello world!", "Click this link."]
    assert_equal ["Hello world!", "Click this link."], doc.text
    
    # Remove the extension.
    assert_equal :a, Wgit::Document.text_elements.delete(:a)
  end

  def test_extending_the_api_define_extension
    # Let's get all the page's table elements.
    Wgit::Document.define_extension(
      :tables,                  # Document#tables will return the page's tables.
      "//table",                # The xpath to extract the tables.
      singleton: false,         # True returns the first table found, false returns all.
      text_content_only: false, # True returns a String of all the tables combined text,
                                # false returns the tables as Nokogiri objects (see below).
    ) do |tables|
      # Here we can manipulate the object(s) before they're set in Document#tables.
    end

    # Our Document has a table which we're interested in.
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p>\
    <table><th>Header Text</th><th>Another Header</th></table></html>"
    )

    # Call our newly defined method to obtain the table data we're interested in.
    tables = doc.tables

    # Both the collection and each table within the collection are plain Nokogiri objects.
    tables.class        # => Nokogiri::XML::NodeSet
    tables.first.class  # => Nokogiri::XML::Element

    assert_equal Nokogiri::XML::NodeSet, tables.class
    assert_equal Nokogiri::XML::Element, tables.first.class

    # Remove the extension.
    Wgit::Document.remove_extension(:tables)
    Wgit::Document.send(:remove_method, :tables)
  end
end
