require_relative 'helpers/test_helper'

# Test class for the Database methods.
# WARNING: The DB is cleared down prior to each test run.
class TestDatabase < TestHelper
  include Wgit::DatabaseHelper

  # Runs before every test.
  def setup
    clear_db

    @url = Wgit::Url.new(Wgit::DatabaseDevData.url)
    @doc = Wgit::Document.new(Wgit::DatabaseDevData.doc)

    @urls = Array.new(3) { Wgit::Url.new(Wgit::DatabaseDevData.url) }
    @docs = Array.new(3) { Wgit::Document.new(Wgit::DatabaseDevData.doc) }
  end

  def test_initialize
    db = Wgit::Database.new
    refute_nil db.connection_string
    refute_nil db.client

    db = Wgit::Database.new ENV['WGIT_CONNECTION_STRING']
    refute_nil db.connection_string
    refute_nil db.client

    reset_connection_string do
      e = assert_raises(StandardError) { Wgit::Database.new }
      assert_equal "connection_string and ENV['WGIT_CONNECTION_STRING'] are nil", e.message
    end
  end

  def test_connect
    db = Wgit::Database.connect
    refute_nil db.connection_string
    refute_nil db.client

    db = Wgit::Database.connect ENV['WGIT_CONNECTION_STRING']
    refute_nil db.connection_string
    refute_nil db.client

    reset_connection_string do
      e = assert_raises(StandardError) { Wgit::Database.connect }
      assert_equal "connection_string and ENV['WGIT_CONNECTION_STRING'] are nil", e.message
    end
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

    e = assert_raises(StandardError) { db.insert true }
    assert_equal 'Unsupported type - TrueClass: true', e.message
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
    assert_empty db.urls
    assert_empty db.crawled_urls
    assert_empty db.uncrawled_urls

    # Seed url data to the DB.
    # Url 1 crawled == true, Url 2 & 3 crawled == false.
    @urls.first.crawled = true
    @urls.map!(&:to_h)
    seed { urls @urls }

    urls = db.urls
    crawled_urls = db.crawled_urls
    uncrawled_urls = db.uncrawled_urls

    # Test urls.
    assert urls.all? { |url| url.instance_of? Wgit::Url }
    assert_equal 3, urls.count

    # Test crawled_urls
    assert crawled_urls.all? { |url| url.instance_of? Wgit::Url }
    assert_equal 1, crawled_urls.count

    # Test uncrawled_urls.
    assert uncrawled_urls.all? { |url| url.instance_of? Wgit::Url }
    assert_equal 2, uncrawled_urls.count
  end

  def test_search
    query = 'Everest Depart Kathmandu'

    @docs.last.text << query
    doc_hashes = @docs.map(&:to_h)
    seed { docs doc_hashes }

    db = Wgit::Database.new

    # Test no results.
    assert_empty db.search "doesn't_exist_123"

    # Test whole_sentence: false.
    results = db.search query
    assert results.all? { |doc| doc.instance_of? Wgit::Document }
    assert_equal @docs.count, results.count

    # Test whole_sentence: true and block.
    count = 0
    results = db.search(query, whole_sentence: true) { count += 1 }

    assert results.all? { |doc| doc.instance_of? Wgit::Document }
    assert_equal 1, count
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

    assert_instance_of Integer, size
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

    seed { url 3; doc 2 }
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

  def test_update__url
    seed { url @url.to_h }
    @url.crawled = true
    db = Wgit::Database.new
    result = db.update @url

    assert_equal 1, result
    assert url? @url.to_h
    refute url? url: @url, crawled: false
  end

  def test_update__doc
    title = 'Climb Everest!'
    seed { doc @doc.to_h }
    @doc.instance_variable_set :@title, title
    db = Wgit::Database.new
    result = db.update @doc

    assert_equal 1, result
    assert doc? @doc.to_h
    refute doc? url: @doc.url, title: 'Altitude Junkies | Everest'
  end

  private

  # Reset the WGIT_CONNECTION_STRING after the block executes.
  def reset_connection_string
    connection_string = ENV.delete 'WGIT_CONNECTION_STRING'
    yield # Run assertions etc. here.
    ENV['WGIT_CONNECTION_STRING'] = connection_string
  end
end
