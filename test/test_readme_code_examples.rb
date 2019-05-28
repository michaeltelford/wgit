require_relative "helpers/test_helper"
require "securerandom"

# Test class for code snippets in the README.md.
# WARNING: The DB is cleared down at the start of the database example test.
class TestReadmeCodeExamples < TestHelper
  include Wgit::DatabaseHelper
  
  # Runs before every test.
  def setup
  end
  
  def test_basic_usage
    ### PUT README CODE BELOW ###
    
    require 'wgit'

    crawler = Wgit::Crawler.new
    url = Wgit::Url.new "https://wikileaks.org/What-is-Wikileaks.html"

    doc = crawler.crawl url

    doc.class # => Wgit::Document
    doc.stats # => {
    # :url=>44, :html=>28133, :title=>17, :keywords=>0,
    # :links=>35, :text_length=>67, :text_bytes=>13735
    #}

    # doc responds to the following methods:
    Wgit::Document.instance_methods(false).sort # => [
    # :==, :[], :author, :doc, :empty?, :external_links, :external_urls,
    # :html, :internal_full_links, :internal_links, :keywords, :links, 
    # :relative_full_links, :relative_full_urls, :relative_links, 
    # :relative_urls, :score, :search, :search!, :size, :stats, :text, 
    # :title, :to_h, :to_hash, :url, :xpath
    #]

    results = doc.search "corruption"
    results.first # => "ial materials involving war, spying and corruption. 
                  #     It has so far published more"

    ### PUT README CODE ABOVE ###

    refute(doc.stats.empty?) # The stats change a lot so just assert presence.
    assert_equal([:==, :[], :author, :css, :date_crawled, :doc, :empty?, :external_links, :external_urls, :html, :internal_full_links, :internal_links, :keywords, :links, :relative_full_links, :relative_full_urls, :relative_links, :relative_urls, :score, :search, :search!, :size, :stats, :text, :title, :to_h, :to_hash, :to_json, :url, :xpath], Wgit::Document.instance_methods(false).sort)
    assert_equal("ial materials involving war, spying and corruption. It has so far published more", results.first)
  end
  
  def test_css_indexer
    ### PUT README CODE BELOW ###

    require 'wgit'
    require 'wgit/core_ext' # Provides the String#to_url and Enumerable#to_urls methods.

    crawler = Wgit::Crawler.new
    url = "https://www.facebook.com".to_url

    doc = crawler.crawl url

    # Provide your own xpath to search the HTML using Nokogiri.
    css_urls = doc.xpath "//link[@rel='stylesheet']/@href"

    css_urls.class # => Nokogiri::XML::NodeSet
    css_url = css_urls.first.value # => "https://static.xx.fbcdn.net/rsrc.php/v3/yE/r/uqWZrDdEiFq.css"

    css = crawler.crawl css_url.to_url
    css[0..50] # => ".UIContentTopper{padding:14px 0 0 17px;margin:50px "

    ### PUT README CODE ABOVE ###

    assert_instance_of Nokogiri::XML::NodeSet, css_urls
    assert css_urls.first.value.start_with?("https://static.xx.fbcdn.net/rsrc.php/v3")
    refute_empty css
  end
  
  def test_keyword_indexer
    ### PUT README CODE BELOW ###

    require 'wgit'

    my_pages_keywords = ["Everest", "mountaineering school", "adventure"]
    my_pages_missing_keywords = []

    competitor_urls = [
      "http://altitudejunkies.com", 
      "http://www.mountainmadness.com", 
      "http://www.adventureconsultants.com"
    ]

    crawler = Wgit::Crawler.new competitor_urls

    crawler.crawl do |doc|
      # If there are keywords present in the web document.
      if doc.keywords.respond_to? :-
        # puts "The keywords for #{doc.url} are: \n#{doc.keywords}\n\n"
        my_pages_missing_keywords.concat(doc.keywords - my_pages_keywords)
      end
    end

    # if my_pages_missing_keywords.empty?
    #   puts "Your pages are missing no keywords, nice one!"
    # else
    #   puts "Your pages compared to your competitors are missing the following keywords:"
    #   puts my_pages_missing_keywords.uniq
    # end

    ### PUT README CODE ABOVE ###

    refute_empty my_pages_missing_keywords.uniq
  end
  
  # Clears the DB and uses the test connection details which are already set.
  def test_database_example
    clear_db

    ### PUT README CODE BELOW AND COMMENT OUT THE SET CONNECTION DETAILS ###

    require 'wgit'
    require 'wgit/core_ext' # => Provides the String#to_url and Enumerable#to_urls methods.

    # Here we create our own document rather than crawling the web.
    # We pass the web page's URL and HTML Strings.
    doc = Wgit::Document.new(
      "http://test-url.com".to_url, 
      "<html><p>How now brown cow.</p><a href='http://www.google.co.uk'>Click me!</a></html>"
    )

    # Set your MongoDB connection details.
    # Wgit.set_connection_details({
    #   'host'  => '<host_machine>',
    #   'port'  => '27017',
    #   'uname' => '<username>',
    #   'pword' => '<password>',
    #   'db'    => '<database_name>',
    # })

    db = Wgit::Database.new
    db.insert doc

    # Searching the database returns documents with matching text 'hits'.
    query = "cow"
    results = db.search query

    doc.url == results.first.url # => true

    # Searching a document returns the matching lines of text within that document.
    doc.search(query).first # => "How now brown cow."

    db.insert doc.external_links

    urls_to_crawl = db.uncrawled_urls # => Results will include doc.external_links. 

    ### PUT README CODE ABOVE ###

    assert_equal doc.url, results.first.url
    assert_equal "How now brown cow.", doc.search(query).first
    assert_equal doc.external_links, urls_to_crawl
  end
  
  def test_extending_the_api_text_elements
    ### PUT README CODE BELOW ###

    require 'wgit'
    require 'wgit/core_ext'

    # Let's add the text of links e.g. <a> tags.
    Wgit::Document.text_elements << :a

    # Our Document has a link whose's text we're interested in.
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p>\
    <a href='https://made-up-link.com'>Click this link.</a></html>"
    )

    # Now all crawled Documents will contain all link text in Wgit::Document#text.
    doc.text # => ["Hello world!", "Click this link."]
    
    ### PUT README CODE ABOVE ###

    assert_equal ["Hello world!", "Click this link."], doc.text
    assert_equal :a, Wgit::Document.text_elements.delete(:a)
  end

  def test_extending_the_api_define_extension
    ### PUT README CODE BELOW ###

    require 'wgit'
    require 'wgit/core_ext'

    # Let's get all the page's table elements.
    Wgit::Document.define_extension(
      :tables,                  # Wgit::Document#tables will return the page's tables.
      "//table",                # The xpath to extract the tables.
      singleton: false,         # True returns the first table found, false returns all.
      text_content_only: false, # True returns a String of all the tables combined text,
                                # false returns the tables as Nokogiri objects (see below).
    ) do |tables|
      # Here we can manipulate the object(s) before they're set in Wgit::Document#tables.
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

    ### PUT README CODE ABOVE ###

    assert_equal tables, doc.tables
    assert_instance_of Nokogiri::XML::NodeSet, tables
    assert_instance_of Nokogiri::XML::Element, tables.first

    # Remove the extension.
    Wgit::Document.remove_extension(:tables)
    Wgit::Document.send(:remove_method, :tables)
  end
end
