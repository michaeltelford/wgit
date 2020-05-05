require_relative 'helpers/test_helper'
require 'securerandom'

# Test class for code snippets in the README.md.
# WARNING: The DB is cleared down at the start of the database example test.
class TestReadmeCodeExamples < TestHelper
  include DatabaseHelper

  # Runs before every test.
  def setup; end

  def test_basic_usage
    ### PUT README CODE BELOW ###

    require 'wgit'

    crawler = Wgit::Crawler.new # Uses Typhoeus -> libcurl underneath. It's fast!
    url = Wgit::Url.new 'https://wikileaks.org/What-is-Wikileaks.html'

    doc = crawler.crawl url # Or use #crawl_site(url) { |doc| ... } etc.
    crawler.last_response.class # => Wgit::Response is a wrapper for Typhoeus::Response.

    doc.class # => Wgit::Document
    doc.class.public_instance_methods(false).sort # => [
    # :==, :[], :author, :base, :base_url, :content, :css, :description, :doc, :empty?,
    # :external_links, :external_urls, :html, :internal_absolute_links,
    # :internal_absolute_urls,:internal_links, :internal_urls, :keywords, :links, :score,
    # :search, :search!, :size, :statistics, :stats, :text, :title, :to_h, :to_json,
    # :url, :xpath
    # ]

    doc.url   # => "https://wikileaks.org/What-is-Wikileaks.html"
    doc.title # => "WikiLeaks - What is WikiLeaks"
    doc.stats # => {
              #   :url=>44, :html=>28133, :title=>17, :keywords=>0,
              #   :links=>35, :text=>67, :text_bytes=>13735
              # }
    doc.links # => ["#submit_help_contact", "#submit_help_tor", "#submit_help_tips", ...]
    doc.text  # => ["The Courage Foundation is an international organisation that <snip>", ...]

    results = doc.search 'corruption' # Searches doc.text for the given query.
    results.first # => "ial materials involving war, spying and corruption.
                  #     It has so far published more"

    ### PUT README CODE ABOVE ###

    assert_instance_of Wgit::Response, crawler.last_response
    assert_equal([:==, :[], :author, :base, :base_url, :content, :css, :description, :doc, :empty?, :external_links, :external_urls, :html, :internal_absolute_links, :internal_absolute_urls, :internal_links, :internal_urls, :keywords, :links, :score, :search, :search!, :size, :statistics, :stats, :text, :title, :to_h, :to_json, :url, :xpath], doc.class.public_instance_methods(false).sort)

    assert_equal 'https://wikileaks.org/What-is-Wikileaks.html', doc.url
    assert_equal 'WikiLeaks - What is WikiLeaks', doc.title
    refute_empty doc.stats # The stats change a lot so just assert presence.
    refute_empty doc.links #  "
    refute_empty doc.text  #  "

    assert_equal 'ial materials involving war, spying and corruption. It has so far published more', results.first
  end

  def test_css_indexer
    ### PUT README CODE BELOW ###

    require 'wgit'
    require 'wgit/core_ext' # Provides the String#to_url and Enumerable#to_urls methods.

    crawler = Wgit::Crawler.new
    url = 'https://www.facebook.com'.to_url

    doc = crawler.crawl url

    # Provide your own xpath (or css selector) to search the HTML using Nokogiri underneath.
    hrefs = doc.xpath "//link[@rel='stylesheet']/@href"

    hrefs.class # => Nokogiri::XML::NodeSet
    href = hrefs.first.value # => "https://static.xx.fbcdn.net/rsrc.php/v3/y1/l/0,cross/NvZ4mNTW3Fd.css"

    css = crawler.crawl href.to_url
    css[0..50] # => "._3_s0._3_s0{border:0;display:flex;height:44px;min-"

    ### PUT README CODE ABOVE ###

    assert_instance_of Nokogiri::XML::NodeSet, hrefs
    assert href.start_with?('https://static.xx.fbcdn.net/rsrc.php/v3')
    refute_empty css
  end

  def test_keyword_indexer
    ### PUT README CODE BELOW ###

    require 'wgit'
    require 'wgit/core_ext' # => Provides the String#to_url and Enumerable#to_urls methods.

    my_pages_keywords = ['Everest', 'mountaineering school', 'adventure']
    my_pages_missing_keywords = []

    competitor_urls = [
      'http://altitudejunkies.com',
      'http://www.mountainmadness.com',
      'http://www.adventureconsultants.com'
    ].to_urls

    crawler = Wgit::Crawler.new

    crawler.crawl(*competitor_urls) do |doc|
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

  def test_database_example
    clear_db

    ##################################################################
    ### PUT README CODE BELOW AND COMMENT OUT THE CONNECTION PARAM ###
    ##################################################################

    require 'wgit'

    ### CONNECT TO THE DATABASE ###

    # In the absence of a connection string parameter, ENV['WGIT_CONNECTION_STRING'] will be used.
    db = Wgit::Database.connect #'<your_connection_string>'

    ### SEED SOME DATA ###

    # Here we create our own document rather than crawling the web (which works in the same way).
    # We provide the web page's URL and HTML Strings.
    doc = Wgit::Document.new(
      'http://test-url.com',
      "<html><p>How now brown cow.</p><a href='http://www.google.co.uk'>Click me!</a></html>"
    )
    db.insert doc

    ### SEARCH THE DATABASE ###

    # Searching the database returns Wgit::Document's which have fields containing the query.
    query = 'cow'
    results = db.search query

    # By default, the MongoDB ranking applies i.e. results.first has the most hits.
    # Because results is an Array of Wgit::Document's, we can custom sort/rank e.g.
    # `results.sort_by! { |doc| doc.url.crawl_duration }` ranks via page load times with
    # results.first being the fastest. Any Wgit::Document attribute can be used, including
    # those you define yourself by extending the API.

    top_result = results.first
    top_result.class           # => Wgit::Document
    doc.url == top_result.url  # => true

    ### PULL OUT THE BITS THAT MATCHED OUR QUERY ###

    # Searching each result gives the matching text snippets from that Wgit::Document.
    top_result.search(query).first # => "How now brown cow."

    ### SEED URLS TO BE CRAWLED LATER ###

    db.insert top_result.external_links
    urls_to_crawl = db.uncrawled_urls # => Results will include top_result.external_links.

    #############################
    ### PUT README CODE ABOVE ###
    #############################

    refute_empty results.sort_by! { |d| d.url.crawl_duration }
    assert_instance_of Wgit::Document, top_result
    assert_equal doc.url, top_result.url
    assert_equal 'How now brown cow.', top_result.search(query).first
    assert_equal urls_to_crawl.length, top_result.external_links.length
  end

  def test_extending_the_api__extend_text_elements
    ### PUT README CODE BELOW ###

    require 'wgit'

    # The default text_elements cover most visible page text but let's say we
    # have a <table> element with text content that we want.
    Wgit::Document.text_elements << :table

    doc = Wgit::Document.new(
      'http://some_url.com',
      <<~HTML
      <html>
        <p>Hello world!</p>
        <table>My table</table>
      </html>
      HTML
    )

    # Now every crawled Document#text will include <table> text content.
    doc.text            # => ["Hello world!", "My table"]
    doc.search('table') # => ["My table"]

    ### PUT README CODE ABOVE ###

    assert_equal ['Hello world!', 'My table'], doc.text
    assert_equal ['My table'], doc.search('table')

    Wgit::Document.text_elements.delete(:table)
  end

  def test_extending_the_api__define_extension
    ### PUT README CODE BELOW ###

    require 'wgit'

    # Let's get all the page's <table> elements.
    Wgit::Document.define_extension(
      :tables,                  # Wgit::Document#tables will return the page's tables.
      '//table',                # The xpath to extract the tables.
      singleton: false,         # True returns the first table found, false returns all.
      text_content_only: false, # True returns the table text, false returns the Nokogiri object.
    ) do |tables|
      # Here we can inspect/manipulate the tables before they're set as Wgit::Document#tables.
      tables
    end

    # Our Document has a table which we're interested in. Note it doesn't matter how the Document
    # is initialised e.g. manually (as below) or via Wgit::Crawler methods etc.
    doc = Wgit::Document.new(
      'http://some_url.com',
      <<~HTML
      <html>
        <p>Hello world! Welcome to my site.</p>
        <table>
          <tr><th>Name</th><th>Age</th></tr>
          <tr><td>Socrates</td><td>101</td></tr>
          <tr><td>Plato</td><td>106</td></tr>
        </table>
        <p>I hope you enjoyed your visit :-)</p>
      </html>
      HTML
    )

    # Call our newly defined method to obtain the table data we're interested in.
    tables = doc.tables

    # Both the collection and each table within the collection are plain Nokogiri objects.
    tables.class       # => Nokogiri::XML::NodeSet
    tables.first.class # => Nokogiri::XML::Element

    # Note, the Document's stats now include our 'tables' extension.
    doc.stats # => {
    #   :url=>19, :html=>242, :links=>0, :text=>8, :text_bytes=>91, :tables=>1
    # }

    ### PUT README CODE ABOVE ###

    assert_equal tables, doc.tables
    assert_instance_of Nokogiri::XML::NodeSet, tables
    assert_instance_of Nokogiri::XML::Element, tables.first
    assert_equal({
      :url=>19, :html=>242, :links=>0, :text=>8, :text_bytes=>91, :tables=>1
    }, doc.stats)

    # Remove the extension.
    Wgit::Document.remove_extension(:tables)
    Wgit::Document.send(:remove_method, :tables)
  end
end
