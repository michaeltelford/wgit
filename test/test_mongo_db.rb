require_relative 'helpers/test_helper'

# Test class for the Database::MongoDB adapter logic.
# WARNING: The DB is cleared down prior to each test run.
class TestMongoDB < TestHelper
  include MongoDBHelper

  # Runs before every test.
  def setup
    Wgit::Model.set_default_search_fields(db)

    empty_db

    @url = Wgit::Url.new(DatabaseTestData.url)
    @doc = Wgit::Document.new(DatabaseTestData.doc)

    @urls = Array.new(3) { Wgit::Url.new(DatabaseTestData.url) }
    @docs = Array.new(3) { Wgit::Document.new(DatabaseTestData.doc) }
  end

  def test_initialize
    db2 = Wgit::Database::MongoDB.new
    refute_nil db2.connection_string
    refute_nil db2.client
    assert_nil db2.last_result

    db2 = Wgit::Database::MongoDB.new ENV['WGIT_CONNECTION_STRING']
    refute_nil db2.connection_string
    refute_nil db2.client
    assert_nil db2.last_result

    reset_connection_string do
      e = assert_raises(StandardError) { Wgit::Database::MongoDB.new }
      assert_equal "connection_string and ENV['WGIT_CONNECTION_STRING'] are nil", e.message
    end
  end

  def test_connect
    db2 = Wgit::Database::MongoDB.connect
    refute_nil db2.connection_string
    refute_nil db2.client
    assert_nil db2.last_result

    db2 = Wgit::Database::MongoDB.connect ENV['WGIT_CONNECTION_STRING']
    refute_nil db2.connection_string
    refute_nil db2.client
    assert_nil db2.last_result

    reset_connection_string do
      e = assert_raises(StandardError) { Wgit::Database::MongoDB.connect }
      assert_equal "connection_string and ENV['WGIT_CONNECTION_STRING'] are nil", e.message
    end
  end

  # We test both methods together for convenience.
  def test_create_collections__unique_indexes
    urls = db.client[Wgit::Database::MongoDB::URLS_COLLECTION]
    docs = db.client[Wgit::Database::MongoDB::DOCUMENTS_COLLECTION]

    urls.drop
    docs.drop

    db.create_collections
    db.create_unique_indexes

    assert_equal 2, urls.indexes.count
    assert_equal 2, docs.indexes.count
  end

  def test_search_fields
    field_strs = Wgit::Model.search_fields.transform_keys(&:to_s)

    # Mimic an extracted field and seed in the DB.
    @doc.instance_variable_set :@code, ['bundle install']
    seed { doc @doc }

    db = Wgit::Database::MongoDB.new
    assert_equal field_strs, db.search_fields
    assert_empty db.search('bundle')

    Wgit::Model.set_search_fields(%i[code], db)
    assert_equal({ 'code' => 1 }, db.search_fields)
    refute_empty db.search('bundle')
  end

  def test_insert__urls
    # Insert 1 url.
    num_inserted = db.insert @url
    assert_equal 1, num_inserted
    refute_nil db.last_result
    assert url?(@url.to_h)
    assert_equal 1, db.num_urls

    # Insert several urls.
    num_inserted = db.insert @urls
    assert_equal @urls.length, num_inserted

    @urls.each { |url| assert url?(url.to_h) }
    assert_equal @urls.length + 1, db.num_urls
    assert_equal db.num_urls, db.num_records

    # Insert an invalid type.
    e = assert_raises(StandardError) { db.insert true }
    assert_equal 'obj must be a Wgit::Url or Wgit::Document, not: TrueClass', e.message

    # Insert a url with redirects.
    url_with_redirects = Wgit::Url.new('http://example.com')
    url_with_redirects.redirects = {'http://example.com' => 'https://example.com'}
    assert_equal 1, db.insert(url_with_redirects)
    assert url?(url_with_redirects.to_h)
  end

  def test_insert__docs
    # Insert 1 doc.
    num_inserted = db.insert @doc
    assert_equal 1, num_inserted
    refute_nil db.last_result
    assert doc?(Wgit::Model.document(@doc))
    assert_equal 1, db.num_docs

    # Insert several docs.
    num_inserted = db.insert @docs
    assert_equal @docs.length, num_inserted
    @docs.each { |doc| assert doc?(Wgit::Model.document(doc)) }
    assert_equal @docs.length + 1, db.num_docs
    assert_equal db.num_docs, db.num_records
  end

  def test_upsert
    assert db.upsert(@url)
    assert_equal 1, db.num_records
    refute_nil db.last_result

    assert db.upsert(@doc)
    assert_equal 2, db.num_records
    refute_nil db.last_result

    @url.crawled = false
    refute db.upsert(@url)
    assert_equal 2, db.num_records
    refute db.get(@url).crawled
  end

  def test_bulk_upsert__urls
    urls = [
      'http://example.com',   # Gets inserted.
      'http://example.com/2', # Gets inserted.
      'http://example.com',   # Dup of 1, will be updated.
      'http://example.com/3'  # Gets inserted.
    ].to_urls
    count = db.bulk_upsert(urls)

    assert_equal 3, count
    assert_equal 3, db.num_urls
    assert_equal 0, db.num_docs
    assert_equal [
      'http://example.com',
      'http://example.com/2',
      'http://example.com/3'
    ], db.urls.map(&:to_s)
    refute_nil db.last_result
  end

  def test_bulk_upsert__docs
    urls = [
      'http://example.com',   # Gets inserted.
      'http://example.com/2', # Gets inserted.
      'http://example.com',   # Dup of 1, will be updated.
      'http://example.com/3'  # Gets inserted.
    ].to_urls
    # Map each of the urls above into a document.
    docs = urls.map do |url|
      doc_hash = DatabaseTestData.doc(url: url, append_suffix: false)
      Wgit::Document.new(doc_hash)
    end

    count = db.bulk_upsert(docs)

    assert_equal 3, count
    assert_equal 3, db.num_docs
    assert_equal 0, db.num_urls
    assert_equal [
      'http://example.com',
      'http://example.com/2',
      'http://example.com/3'
    ], db.docs.map(&:url)
    refute_nil db.last_result
  end

  def test_docs
    # Test empty docs result.
    assert_empty db.docs

    seed { docs @docs }
    docs = db.docs

    # Test non empty docs results.
    assert docs.all? { |doc| doc.instance_of? Wgit::Document }
    assert_equal 3, docs.length
    refute_nil db.last_result

    # Test limit and skip.
    assert_equal @docs[1], db.docs(skip: 1, limit: 1).first
  end

  def test_urls
    # Test empty urls result.
    assert_empty db.urls
    assert_empty db.crawled_urls
    assert_empty db.uncrawled_urls

    refute_nil db.last_result

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

  def test_urls__with_redirects
    # Seed url data to the DB.
    # Url with redirects populated.
    redirects_hash = {'http://example.com' => 'https://example.com'}
    @urls.first.redirects = redirects_hash
    seed { urls @urls }

    urls = db.urls

    # Test urls.
    assert urls.all? { |url| url.instance_of? Wgit::Url }
    assert_equal 3, urls.length
    assert_equal redirects_hash, urls.first.redirects
  end

  def test_search__case_sensitive
    @docs.last.text << 'Foo Bar'
    seed { docs @docs }

    # Test no results.
    assert_empty db.search('doesnt_exist_123')
    refute_nil db.last_result

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
  end

  def test_search__whole_sentence
    @docs.last.text << 'Foo Bar'
    seed { docs @docs }

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

  def test_search__limit
    # First doc has highest textScore and so on...
    @docs.reverse.each_with_index do |doc, i|
      i.times { doc.text << 'Everest' }
    end
    seed { docs @docs }

    # Test search.
    assert_equal 3, db.search('everest').length
    assert_equal 3, db.last_result&.count

    # Test limit.
    results = db.search('everest', limit: 2)
    assert_equal 2, results.length
    assert_equal 3, db.last_result&.count

    results.each_with_index do |doc, i|
      doc.instance_of? Wgit::Document
      assert_equal @docs[i], doc
      assert_equal @docs[i].url.to_h, doc.url.to_h
    end
  end

  def test_search__skip
    # First doc has highest textScore and so on...
    @docs.reverse.each_with_index do |doc, i|
      i.times { doc.text << 'Everest' }
    end
    seed { docs @docs }

    # Test skip.
    results = db.search('everest', skip: 1)
    assert_equal 2, results.length
    assert_equal 3, db.last_result&.count

    results.each_with_index do |doc, i|
      doc.instance_of? Wgit::Document
      assert_equal @docs[i + 1], doc
      assert_equal @docs[i + 1].url.to_h, doc.url.to_h
    end

    # Test limit and skip.
    results = db.search('everest', limit: 1, skip: 1)
    assert_equal 1, results.length
    assert_equal 3, db.last_result&.count

    results.each do |doc|
      doc.instance_of? Wgit::Document
      assert_equal @docs[1], doc
      assert_equal @docs[1].url.to_h, doc.url.to_h
    end
  end

  def test_search__default_search_fields
    # => title    (2 hit  * 2 weight == 4)
    # => text     (3 hits * 1 weight == 3)
    # => keywords (1 hits * 2 weight == 2)
    # => keywords (1 hits * 2 weight == 2)
    # ------------------------------------
    # => Total match score:          == 11
    test_doc = Wgit::Document.new({
      'url' => 'http://www.mytestsite.com/home',
      'title' => 'abc abc',
      'keywords' => ['abc 2', 'abc 3'],
      'text' => 'abc abc abc'
    })
    seed { doc test_doc }

    results = db.search('abc')

    assert_equal(1, results.size)
    assert_equal(7.75, results.first.score)
  end

  def test_search__set_search_fields
    Wgit::Model.set_search_fields(%i[code foo], db) # @code exists, @foo doesn't.

    test_doc = Wgit::Document.new('http://www.mytestsite.com/home')
    test_doc.instance_variable_set(:@code, 'print("hello world")') # Score of 1.
    seed { doc test_doc }

    results = db.search('hello')

    assert_equal(1, results.size)
    assert_equal(0.67, results.first.score.round(2))
  end

  def test_search!
    # All dev data @docs contain the word 'peak' in the text.
    # And doc has 'peak' in the title.
    html = '<html><head><title>peak</title></head></html>'
    doc  = Wgit::Document.new 'http://example.com'.to_url, html
    doc2 = Wgit::Document.new 'https://example.com'.to_url, '<html>FooBar</html>'
    test_docs = @docs + [doc, doc2] # 5 docs in total, 4 matching.
    seed { docs test_docs }

    query = 'peak'
    expected_matches = [
      'Highest Peak',
      'All climbers need to have climbed on a 7,000-8,000-meter peak previously',
      '8,000-meter peaks are a serious undertaking and climbers need to be aware there ',
      ' a 7,000-meter or 8,000-meter Himalayan peak to qualify for our expedition. We d',
      '· Expedition permit, peak fee and conservation fees'
    ]

    results     = db.search!(query)
    top_results = db.search!(query, top_result_only: true)

    assert_equal 4, results.size
    assert_equal 4, db.last_result&.count
    assert_instance_of Hash, results
    assert_instance_of Hash, top_results

    assert(results.values.first(3).all? { |matches| matches == expected_matches })
    assert(top_results.values.first(3).all? { |match| match == 'Highest Peak' })

    assert_equal ['peak'], results.values.last
    assert_equal 'peak', top_results.values.last
  end

  def test_stats
    stats = db.stats

    refute_nil stats
    refute stats.empty?
  end

  def test_size
    assert db.size.zero?
  end

  def test_num_urls
    assert_equal 0, db.num_urls

    seed { url 3 }
    assert_equal 3, db.num_urls
  end

  def test_num_docs
    assert_equal 0, db.num_docs

    seed { doc 3 }
    assert_equal 3, db.num_docs
  end

  def test_num_records
    assert_equal 0, db.num_records

    seed { url 3; doc 2 }
    assert_equal 5, db.num_records
  end

  def test_url?
    refute db.url? @url

    seed { url @url }
    assert db.url? @url
  end

  def test_doc?
    refute db.doc? @doc

    seed { doc @doc }
    assert db.doc? @doc
  end

  def test_exists?
    refute db.exists?(@url)

    seed { url @url }
    assert db.exists?(@url)
  end

  def test_get
    seed do
      url @url
      doc @doc
    end

    result = db.get(@url)
    refute_nil db.last_result
    assert_instance_of Wgit::Url, result
    assert_equal @url.to_h, result.to_h

    result = db.get(@doc)
    refute_nil db.last_result
    assert_instance_of Wgit::Document, result
    assert_equal @doc.to_h, result.to_h
  end

  def test_get__empty
    ex = assert_raises(StandardError) { db.get 1 }
    assert_equal 'obj must be a Wgit::Url or Wgit::Document, not: Integer', ex.message

    assert_nil db.get(@url)
    refute_nil db.last_result
  end

  def test_update__url
    seed { url @url }
    @url.crawled = false
    result = db.update @url

    assert_equal 1, result
    refute_nil db.last_result
    assert url? @url.to_h
    refute url? url: @url, crawled: true
  end

  def test_update__doc
    title = 'Climb Everest!'
    seed { doc @doc }
    @doc.title = title
    result = db.update @doc

    assert_equal 1, result
    refute_nil db.last_result
    assert doc?(Wgit::Model.document(@doc))
    refute doc? url: @doc.url, title: 'Altitude Junkies | Everest'
  end

  def test_delete
    assert_equal 0, db.delete(@url)
    refute_nil db.last_result

    seed { url @url }
    assert_equal 1, db.delete(@url)

    seed { doc @doc }
    assert_equal 1, db.delete(@doc)

    ex = assert_raises(StandardError) { db.delete 1 }
    assert_equal 'obj must be a Wgit::Url or Wgit::Document, not: Integer', ex.message
  end

  def test_empty_urls
    seed { urls 3 }

    assert_equal 3, db.empty_urls
    assert_equal 0, db.num_urls
  end

  def test_empty_docs
    seed { docs 3 }

    assert_equal 3, db.empty_docs
    assert_equal 0, db.num_docs
  end

  def test_empty
    seed do
      urls 3
      docs 2
    end

    assert_equal 5, db.empty
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
