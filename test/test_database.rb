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
    assert doc?(Wgit::Model.document(@doc))
    assert_equal 1, db.num_docs

    # Insert several docs.
    num_inserted = db.insert @docs
    assert_equal @docs.length, num_inserted
    @docs.each { |doc| assert doc?(Wgit::Model.document(doc)) }
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
    # Url 1 crawled == false, Url 2 & 3 crawled == true.
    @urls.first.crawled = false
    seed { urls @urls }

    urls = db.urls
    crawled_urls = db.crawled_urls
    uncrawled_urls = db.uncrawled_urls

    # Test urls.
    assert urls.all? { |url| url.instance_of? Wgit::Url }
    assert_equal 3, urls.length

    # Test crawled_urls
    assert crawled_urls.all? { |url| url.instance_of? Wgit::Url }
    assert_equal 2, crawled_urls.length

    # Test uncrawled_urls.
    assert uncrawled_urls.all? { |url| url.instance_of? Wgit::Url }
    assert_equal 1, uncrawled_urls.length
  end

  def test_search__case_sensitive__whole_sentence
    @docs.last.text << 'Foo Bar'

    seed { docs @docs }

    db = Wgit::Database.new

    # Test no results.
    assert_empty db.search('doesnt_exist_123')

    # Test case_sensitive: false and block.
    count = 0
    results = db.search('foo bar', case_sensitive: false) do |doc|
      assert_instance_of Wgit::Document, doc
      count += 1
    end
    assert_equal 1, count
    assert_equal 1, results.length
    assert results.all? { |doc| doc.instance_of? Wgit::Document }

    # Test case_sensitive: true.
    assert_empty db.search('foo bar', case_sensitive: true)

    # Test whole_sentence: false.
    results = db.search('bar foo', whole_sentence: false)
    assert_equal 1, results.length
    assert results.all? { |doc| doc.instance_of? Wgit::Document }

    # Test whole_sentence: true.
    assert_empty db.search('bar foo', whole_sentence: true)

    # Test case_sensitive: true and whole_sentence: true.
    results = db.search('Foo Bar', case_sensitive: true, whole_sentence: true)
    assert_equal 1, results.length
    assert results.all? { |doc| doc.instance_of? Wgit::Document }
  end

  def test_search__limit__skip
    # All dev data docs contain the word 'Everest'.
    seed { docs @docs }

    db = Wgit::Database.new

    assert_equal 3, db.search('everest').length

    # Test limit.
    results = db.search('everest', limit: 2)
    assert_equal 2, results.length
    results.each_with_index do |doc, i|
      doc.instance_of? Wgit::Document
      assert_equal @docs[i], doc
      assert_equal @docs[i].url.to_h, doc.url.to_h
    end

    # Test skip.
    results = db.search('everest', skip: 1)
    assert_equal 2, results.length
    results.each_with_index do |doc, i|
      doc.instance_of? Wgit::Document
      assert_equal @docs[i + 1], doc
      assert_equal @docs[i + 1].url.to_h, doc.url.to_h
    end

    # Test limit and skip.
    results = db.search('everest', limit: 1, skip: 1)
    assert_equal 1, results.length
    results.each do |doc|
      doc.instance_of? Wgit::Document
      assert_equal @docs[1], doc
      assert_equal @docs[1].url.to_h, doc.url.to_h
    end
  end

  def test_stats
    db = Wgit::Database.new
    stats = db.stats

    refute_nil stats
    refute stats.empty?
  end

  def test_size
    db = Wgit::Database.new

    assert db.size.zero?
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

    seed { url @url }
    assert db.url? @url
  end

  def test_doc?
    db = Wgit::Database.new
    refute db.doc? @doc

    seed { doc @doc }
    assert db.doc? @doc
  end

  def test_update__url
    seed { url @url }
    @url.crawled = false
    db = Wgit::Database.new
    result = db.update @url

    assert_equal 1, result
    assert url? @url.to_h
    refute url? url: @url, crawled: true
  end

  def test_update__doc
    title = 'Climb Everest!'
    seed { doc @doc }
    @doc.instance_variable_set :@title, title
    db = Wgit::Database.new
    result = db.update @doc

    assert_equal 1, result
    assert doc?(Wgit::Model.document(@doc))
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
