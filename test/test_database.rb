require_relative 'helpers/test_helper'

# Test class for the Database methods.
# WARNING: The DB is cleared down prior to each test run.
class TestDatabase < TestHelper
  include DatabaseHelper

  # Runs before every test.
  def setup
    clear_db

    @url = Wgit::Url.new(DatabaseTestData.url)
    @doc = Wgit::Document.new(DatabaseTestData.doc)

    @urls = Array.new(3) { Wgit::Url.new(DatabaseTestData.url) }
    @docs = Array.new(3) { Wgit::Document.new(DatabaseTestData.doc) }
  end

  # Runs after every test.
  def teardown
    # Reset the text index for other tests.
    db = Wgit::Database.new
    db.text_index = Wgit::Database::DEFAULT_TEXT_INDEX
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

  # We test both methods together for convenience.
  def test_create_collections__unique_indexes
    db = Wgit::Database.new

    urls = db.client[Wgit::Database::URLS_COLLECTION]
    docs = db.client[Wgit::Database::URLS_COLLECTION]

    urls.drop
    docs.drop

    db.create_collections
    db.create_unique_indexes

    assert_equal 2, urls.indexes.count
    assert_equal 2, docs.indexes.count
  end

  def test_text_index__default_index
    db = Wgit::Database.new

    assert_equal Wgit::Database::DEFAULT_TEXT_INDEX, db.text_index
  end

  def test_text_index_equals__fails
    db = Wgit::Database.new

    ex = assert_raises(StandardError) { db.text_index = true }
    assert_equal 'fields must be an Array or Hash, not a TrueClass', ex.message
  end

  def test_text_index_equals__symbols
    db = Wgit::Database.new
    index = db.text_index = %i[title code]

    assert_equal(%i[title code], index)
    assert_equal({ title: 1, code: 1 }, db.text_index)
  end

  def test_text_index_equals__hash
    db = Wgit::Database.new
    index = db.text_index = { title: 2, code: 1 }

    assert_equal({ title: 2, code: 1 }, index)
    assert_equal({ title: 2, code: 1 }, db.text_index)
  end

  def test_text_index__search_results
    # Mimic an extracted field and seed in the DB.
    @doc.instance_variable_set :@code, ['bundle install']
    seed { doc @doc }

    db = Wgit::Database.new
    assert_empty db.search('bundle')

    db.text_index = %i[code]
    refute_empty db.search('bundle')
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
    assert_equal 'obj must be a Wgit::Url or Wgit::Document, not: TrueClass', e.message
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

  def test_docs
    db = Wgit::Database.new

    # Test empty docs result.
    assert_empty db.docs

    seed { docs @docs }
    docs = db.docs

    # Test non empty docs results.
    assert docs.all? { |doc| doc.instance_of? Wgit::Document }
    assert_equal 3, docs.length

    # Test limit and skip.
    assert_equal @docs[1], db.docs(skip: 1, limit: 1).first
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

    # Test limit and skip.
    assert_equal @urls[1], db.urls(skip: 1, limit: 1).first
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

  def test_search!
    @docs.last.text << 'Foo Bar'

    seed { docs @docs }

    db = Wgit::Database.new

    # Assert the result doc's text contains the query.
    match = nil
    results = db.search!('foo bar') do |doc|
      assert_instance_of Wgit::Document, doc
      match = doc
    end

    assert_equal 1, results.length
    assert results.all? { |doc| doc.instance_of? Wgit::Document }
    assert results.first.object_id, match.object_id
    assert_equal ['Foo Bar'], match.text
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

  def test_exists?
    db = Wgit::Database.new
    refute db.exists?(@url)

    seed { url @url }
    assert db.exists?(@url)
  end

  def test_get
    db = Wgit::Database.new

    seed do
      url @url
      doc @doc
    end

    result = db.get(@url)
    assert_instance_of Wgit::Url, result
    assert_equal @url.to_h, result.to_h

    result = db.get(@doc)
    assert_instance_of Wgit::Document, result
    assert_equal @doc.to_h, result.to_h
  end

  def test_get__empty
    db = Wgit::Database.new

    ex = assert_raises(StandardError) { db.get 1 }
    assert_equal 'obj must be a Wgit::Url or Wgit::Document, not: Integer', ex.message

    assert_nil db.get(@url)
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

  def test_delete
    db = Wgit::Database.new
    assert_equal 0, db.delete(@url)

    seed { url @url }
    assert_equal 1, db.delete(@url)

    seed { doc @doc }
    assert_equal 1, db.delete(@doc)

    ex = assert_raises(StandardError) { db.delete 1 }
    assert_equal 'obj must be a Wgit::Url or Wgit::Document, not: Integer', ex.message
  end

  def test_clear_urls
    seed { urls 3 }
    db = Wgit::Database.new

    assert_equal 3, db.clear_urls
    assert_equal 0, db.num_urls
  end

  def test_clear_docs
    seed { docs 3 }
    db = Wgit::Database.new

    assert_equal 3, db.clear_docs
    assert_equal 0, db.num_docs
  end

  def test_clear_db
    seed do
      urls 3
      docs 2
    end
    db = Wgit::Database.new

    assert_equal 5, db.clear_db
    assert_equal 0, db.num_records
  end

  private

  # Reset the WGIT_CONNECTION_STRING after the block executes.
  def reset_connection_string
    connection_string = ENV.delete 'WGIT_CONNECTION_STRING'
    yield # Run assertions etc. here.
    ENV['WGIT_CONNECTION_STRING'] = connection_string
  end
end
