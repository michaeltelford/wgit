require "minitest/autorun"
require "minitest/pride"
require_relative "helpers/test_helper"
require_relative "../lib/wgit/assertable"
require_relative "../lib/wgit/url"
require_relative "../lib/wgit/document"
require_relative "../lib/wgit/database/database"
require_relative "../lib/wgit/database/database_helper"
require_relative "../lib/wgit/database/database_default_data"

# Test class for the Database methods.
# The classes Url and Document are required types for some Database logic.
# WARNING: The DB is cleared down prior to each test run.
class TestDatabase < Minitest::Test
  include TestHelper
  include Wgit::Assertable
  include Wgit::DatabaseHelper
  
  # Runs before every test.
  def setup
    clear_db
    
    @url = Wgit::Url.new(Wgit::DatabaseDefaultData.url)
    @doc = Wgit::Document.new(Wgit::DatabaseDefaultData.doc)
    
    records = 3
    
    @urls = []
    records.times do
      @urls << Wgit::Url.new(Wgit::DatabaseDefaultData.url)
    end
    
    @docs = []
    records.times do 
      @docs << Wgit::Document.new(Wgit::DatabaseDefaultData.doc)
    end
  end
  
  def test_initialize_connects_to_db
    Wgit::Database.new
    pass
  rescue
    flunk
  end
  
  def test_insert_urls
    db = Wgit::Database.new
    
    # Insert 1 url.
    num_inserted = db.insert @url
    assert_equal 1, num_inserted
    assert url?(@url.to_h)
    assert_equal 1, db.num_urls
    
    # Insert several urls.
    num_inserted = db.insert @urls
    assert_equal @urls.length, num_inserted
    @urls.each { |url| assert url?(url.to_h) }
    assert_equal @urls.length + 1, db.num_urls
    
    assert_equal db.num_urls, db.num_records
  end
  
  def test_insert_docs
    db = Wgit::Database.new
    
    # Insert 1 doc.
    num_inserted = db.insert @doc
    assert_equal 1, num_inserted
    assert doc?(@doc.to_h)
    assert_equal 1, db.num_docs
    
    # Insert several docs.
    num_inserted = db.insert @docs
    assert_equal @docs.length, num_inserted
    @docs.each { |doc| assert doc?(doc.to_h) }
    assert_equal @docs.length + 1, db.num_docs
    
    assert_equal db.num_docs, db.num_records
  end
  
  def test_urls
    db = Wgit::Database.new
    
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
    assert_arr_types urls, Wgit::Url
    assert_equal 3, urls.count
    
    # Test crawled_urls
    assert_arr_types crawled_urls, Wgit::Url
    assert_equal 1, crawled_urls.count
    
    # Test uncrawled_urls.
    assert_arr_types uncrawled_urls, Wgit::Url
    assert_equal 2, uncrawled_urls.count
  end
  
  def test_search
    query = "Everest Depart Kathmandu"
    
    @docs.last.text << query
    doc_hashes = @docs.map { |doc| doc.to_h }
    seed { docs doc_hashes }
    
    db = Wgit::Database.new
    
    # Test no results.
    assert_empty_array db.search "doesn't_exist_123"
    
    # Test whole_sentence = false.
    results = db.search query
    assert_arr_types results, Wgit::Document
    assert_equal @docs.count, results.count
    
    # Test whole_sentence = true and block.
    num_results_from_block = 0
    results = db.search(query, true) { num_results_from_block += 1 }
    assert_arr_types results, Wgit::Document
    assert_equal 1, num_results_from_block
    assert_equal 1, results.count
    assert_equal @docs.last.url, results.last.url
  end
  
  def test_stats
    db = Wgit::Database.new
    stats = db.stats
    refute_nil stats
    refute stats.empty?
  end
  
  def test_size
    db = Wgit::Database.new
    size = db.size
    assert_type size, Float
    refute_nil size
  end

  def test_num_urls
    db = Wgit::Database.new
    assert_equal 0, db.num_urls
    seed { url 3 }
    assert_equal 3, db.num_urls
  end

  def test_num_docs
    db = Wgit::Database.new
    assert_equal 0, db.num_docs
    seed { doc 3 }
    assert_equal 3, db.num_docs
  end

  def test_num_records
    db = Wgit::Database.new
    assert_equal 0, db.num_records
    seed do
      url 3
      doc 2
    end
    assert_equal 5, db.num_records
  end

  def test_url?
    db = Wgit::Database.new
    refute db.url? @url
    seed { url @url.to_h }
    assert db.url? @url
  end

  def test_doc?
    db = Wgit::Database.new
    refute db.doc? @doc
    refute db.doc? @doc.url.to_s
    seed { doc @doc.to_h }
    assert db.doc? @doc
    assert db.doc? @doc.url.to_s
  end

  def test_update_url
    seed { url @url.to_h }
    @url.crawled = true
    db = Wgit::Database.new
    result = db.update @url
    assert_equal 1, result
    assert url? @url.to_h
    refute url? url: @url, crawled: false
  end
  
  def test_update_doc
    title = "Climb Everest!"
    seed { doc @doc.to_h }
    set_doc_title(@doc, title)
    db = Wgit::Database.new
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
