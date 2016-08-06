require "minitest/autorun"
require_relative "helpers/test_helper"
require_relative "../lib/pinch/assertable"
require_relative "../lib/pinch/url"
require_relative "../lib/pinch/document"
require_relative "../lib/pinch/database/database"
require_relative "../lib/pinch/database/database_helper"
require_relative "../lib/pinch/database/database_default_data"

# @author Michael Telford
# Test class for the Database methods.
# The classes Url and Document are required types for some Database logic.
# WARNING: The DB is cleared down prior to each test run.
class TestDatabase < Minitest::Test
  include TestHelper
  include Assertable
  include DatabaseHelper
  
  # Runs before every test.
  def setup
    clear
    @url = Url.new(DatabaseDefaultData.url)
    @doc = Document.new(DatabaseDefaultData.doc)
    num_records = 3
    @urls = []
    num_records.times { @urls << Url.new(DatabaseDefaultData.url) }
    @docs = []
    num_records.times { @docs << Document.new(DatabaseDefaultData.doc) }
  end
  
  def test_initialize_connects_to_db
    Database.new
    pass
  rescue
    flunk
  end
  
  def test_insert_urls
    db = Database.new
    
    # Insert 1 url.
    num_inserted = db.insert @url
    assert_equal 1, num_inserted
    assert url?(@url.to_h)
    assert_equal 1, num_urls
    
    # Insert several urls.
    num_inserted = db.insert @urls
    assert_equal @urls.length, num_inserted
    @urls.each { |url| assert url?(url.to_h) }
    assert_equal @urls.length + 1, num_urls
    
    assert_equal num_urls, num_records
  end
  
  def test_insert_docs
    db = Database.new
    
    # Insert 1 doc.
    num_inserted = db.insert @doc
    assert_equal 1, num_inserted
    assert doc?(@doc.to_h)
    assert_equal 1, num_docs
    
    # Insert several docs.
    num_inserted = db.insert @docs
    assert_equal @docs.length, num_inserted
    @docs.each { |doc| assert doc?(doc.to_h) }
    assert_equal @docs.length + 1, num_docs
    
    assert_equal num_docs, num_records
  end
  
  def test_urls
    db = Database.new
    
    # Test empty urls result.
    assert_empty_array db.urls
    assert_empty_array db.crawled_urls
    assert_empty_array db.uncrawled_urls
    
    # Seed url data to the DB.
    # Url 1 crawled == true, Url 2 & 3 crawled == false.
    @urls.first.crawled = true
    @urls.map! { |url| url.to_h }
    seed { urls @urls }
    
    urls = db.urls
    crawled_urls = db.crawled_urls
    uncrawled_urls = db.uncrawled_urls
    
    # Test urls.
    assert_arr_types urls, Url
    assert_equal 3, urls.count
    
    # Test crawled_urls
    assert_arr_types crawled_urls, Url
    assert_equal 1, crawled_urls.count
    
    # Test uncrawled_urls.
    assert_arr_types uncrawled_urls, Url
    assert_equal 2, uncrawled_urls.count
  end
  
  def test_search
    search_text = "Everest Depart Kathmandu"
    
    @docs.last.text << search_text
    doc_hashes = @docs.map { |doc| doc.to_h }
    seed { docs doc_hashes }
    
    db = Database.new
    
    # Test no results.
    assert_empty_array db.search "doesn't_exist_123"
    
    # Test whole_sentence = false.
    results = db.search search_text
    assert_arr_types results, Document
    assert_equal @docs.count, results.count
    
    # Test whole_sentence = true.
    results = db.search search_text, true
    assert_arr_types results, Document
    assert_equal 1, results.count
    assert_equal @docs.last.url, results.last.url
  end
  
  def test_stats
    db = Database.new
    stats = db.stats
    refute_nil stats
    refute stats.empty?
  end
  
  def test_size
    db = Database.new
    size = db.size
    refute_nil size
    assert_type size, Float
  end
  
  def test_update_url
    seed { url @url.to_h }
    @url.crawled = true
    db = Database.new
    result = db.update @url
    assert_equal 1, result
    assert url? @url.to_h
    refute url? url: @url, crawled: false
  end
  
  def test_update_doc
    title = "Climb Everest!"
    seed { doc @doc.to_h }
    set_doc_title(@doc, title)
    db = Database.new
    result = db.update @doc
    assert_equal 1, result
    assert doc? @doc.to_h
    refute doc? url: @doc.url, title: "Altitude Junkies | Everest"
  end
  
private
  
  # Method which sets the title attribute of a Document object.
  # We define a singleton method on the doc because @title is read only.
  def set_doc_title(doc, title)
    def doc.title=(value)
      @title = value
    end
    doc.title = title
  end
  
  # Assertion helper method.
  def assert_empty_array(array)
    assert_type array, Array
    assert_empty array
  end
end
