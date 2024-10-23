require_relative "helpers/test_helper"

# Test class for the Database::InMemory adapter logic.
# WARNING: The in-memory DB is cleared down prior to each test run.
class TestInMemory < TestHelper
  include InMemoryHelper

  # Runs before every test.
  def setup
    Wgit::Model.set_default_search_fields

    empty_db

    @url = Wgit::Url.new(DatabaseTestData.url)
    @doc = Wgit::Document.new(DatabaseTestData.doc)

    @urls = Array.new(3) { Wgit::Url.new(DatabaseTestData.url) }
    @docs = Array.new(3) { Wgit::Document.new(DatabaseTestData.doc) }
  end

  # Runs after every test.
  def teardown
    # Remove any defined extractors to avoid interfering with other tests.
    return unless Wgit::Document.remove_extractor(:code)

    Wgit::Document.send(:remove_method, :code)
  end

  def test_initialize
    db2 = Wgit::Database::InMemory.new

    refute_nil db2
    assert_empty db2.urls
    assert_empty db2.docs
  end

  def test_bulk_upsert__urls
    urls = [
      "http://example.com",   # Gets inserted.
      "http://example.com/2", # Gets inserted.
      "http://example.com",   # Dup of 1, will be updated.
      "http://example.com/3"  # Gets inserted.
    ].to_urls
    count = db.bulk_upsert(urls)

    assert_equal 3, count
    assert_equal([
      "http://example.com",
      "http://example.com/2",
      "http://example.com/3"
    ], db.urls)
  end

  def test_bulk_upsert__docs
    urls = [
      "http://example.com",   # Gets inserted.
      "http://example.com/2", # Gets inserted.
      "http://example.com",   # Dup of urls[0], will be updated.
      "http://example.com/3"  # Gets inserted.
    ].to_urls

    # Map each of the urls above into a document.
    docs = urls.map do |url|
      doc_hash = DatabaseTestData.doc(url: url, append_suffix: false)
      Wgit::Document.new(doc_hash)
    end

    count = db.bulk_upsert(docs)

    assert_equal 3, count
    assert_equal([
      "http://example.com",
      "http://example.com/2",
      "http://example.com/3"
    ], db.docs.map(&:url))
  end

  def test_docs
    # Test empty docs result.
    assert_empty db.docs

    seed { docs @docs }
    docs = db.docs

    # Test non empty docs results.
    assert(docs.all? { |doc| doc.instance_of? Wgit::Document })
    assert_equal 3, docs.length
  end

  def test_urls
    # Test empty urls result.
    assert_empty db.urls
    assert_empty db.uncrawled_urls

    # Seed url data to the DB.
    # Url 1 crawled == false, Url 2 & 3 crawled == true.
    @urls.first.crawled = false
    seed { urls @urls }

    urls = db.urls
    uncrawled_urls = db.uncrawled_urls

    # Test urls.
    assert(urls.all? { |url| url.instance_of? Wgit::Url })
    assert_equal 3, urls.length

    # Test uncrawled_urls.
    assert(uncrawled_urls.all? { |url| url.instance_of? Wgit::Url })
    assert_equal 1, uncrawled_urls.length
  end

  def test_urls__with_redirects
    # Seed url data to the DB.
    # Url with redirects populated.
    redirects_hash = { "http://example.com" => "https://example.com" }
    @urls.first.redirects = redirects_hash
    seed { urls @urls }

    urls = db.urls

    # Test urls.
    assert(urls.all? { |url| url.instance_of? Wgit::Url })
    assert_equal 3, urls.length
    assert_equal redirects_hash, urls.first.redirects
  end

  def test_search
    # doc1 = 1.0 (match), doc2 = 0.0, doc3 = 2.0
    @docs.first.text << "Foo Bar"
    @docs.last.text << "Foo Bar"
    @docs.last.text << "foO bAr"

    seed { docs @docs }

    # Test no results.
    assert_empty db.search("doesnt_exist_123")

    # Test two results sorted by relevance.
    results = db.search("foo bar")

    assert_equal 2, results.length
    results.all? { |doc| doc.instance_of? Wgit::Document }

    assert_equal @docs.last.url, results.first.url
    assert_equal @docs.first.url, results.last.url
    assert results.first.score > results.last.score
  end

  def test_search__case_sensitive
    @docs.last.text << "Foo Bar"
    seed { docs @docs }

    # Test case_sensitive: false and block.
    count = 0
    results = db.search("foo bar", case_sensitive: false) do |doc|
      assert_instance_of Wgit::Document, doc
      count += 1
    end
    assert_equal 1, count
    assert_equal 1, results.length
    assert(results.all? { |doc| doc.instance_of? Wgit::Document })

    # Test case_sensitive: true.
    assert_empty db.search("foo bar", case_sensitive: true)
  end

  def test_search__whole_sentence
    @docs.last.text << "Foo Bar"
    seed { docs @docs }

    # Test whole_sentence: false.
    results = db.search("bar foo", whole_sentence: false)
    assert_equal 1, results.length
    assert results.first.instance_of?(Wgit::Document)

    # Test whole_sentence: true.
    assert_empty db.search("bar foo", whole_sentence: true)

    # Test case_sensitive: true and whole_sentence: true.
    results = db.search("Foo Bar", case_sensitive: true, whole_sentence: true)
    assert_equal 1, results.length
    assert results.first.instance_of?(Wgit::Document)
  end

  def test_search__limit
    # First doc has highest textScore and so on...
    @docs.reverse.each_with_index do |doc, i|
      i.times { doc.text << "Everest" }
    end
    seed { docs @docs }

    assert_equal 3, db.search("everest").length

    # Test limit.
    results = db.search("everest", limit: 2)
    assert_equal 2, results.length

    results.each_with_index do |doc, i|
      doc.instance_of? Wgit::Document
      assert_equal @docs[i], doc
      assert_equal @docs[i].url.to_h, doc.url.to_h
    end
  end

  def test_search__skip
    # First doc has highest textScore and so on...
    @docs.reverse.each_with_index do |doc, i|
      i.times { doc.text << "Everest" }
    end
    seed { docs @docs }

    # Test skip.
    results = db.search("everest", skip: 1)
    assert_equal 2, results.length

    results.each_with_index do |doc, i|
      doc.instance_of? Wgit::Document
      assert_equal @docs[i + 1], doc
      assert_equal @docs[i + 1].url.to_h, doc.url.to_h
    end

    # Test limit and skip.
    results = db.search("everest", limit: 1, skip: 1)
    assert_equal 1, results.length

    results.each do |doc|
      doc.instance_of? Wgit::Document
      assert_equal @docs[1], doc
      assert_equal @docs[1].url.to_h, doc.url.to_h
    end
  end

  def test_search__special_char
    @doc = Wgit::Document.new @url, <<~HTML
      <p>Hello, this is to test :colon text searches</p>
    HTML

    seed { doc @doc }

    # Test the result comes back.
    results = db.search(":colon")

    assert_equal 1, results.length
    results.all? { |doc| doc.instance_of? Wgit::Document }
  end

  def test_search__default_search_fields
    # => title    (2 hit  * 2 weight == 4)
    # => text     (3 hits * 1 weight == 3)
    # => keywords (1 hits * 2 weight == 2)
    # => keywords (1 hits * 2 weight == 2)
    # ------------------------------------
    # => Total match score:          == 11
    test_doc = Wgit::Document.new({
      "url" => "http://www.mytestsite.com/home",
      "title" => "abc abc",
      "keywords" => ["abc 2", "abc 3"],
      "text" => "abc abc abc"
    })
    seed { doc test_doc }

    results = db.search("abc")

    assert_equal(1, results.size)
    assert_equal(11, results.first.score)
  end

  def test_search__set_search_fields
    Wgit::Document.define_extractor(:code, nil)
    Wgit::Model.set_search_fields(%i[code foo]) # @code exists, @foo doesn't.

    test_doc = Wgit::Document.new("http://www.mytestsite.com/home")
    test_doc.instance_variable_set(:@code, 'print("hello world")') # Score of 1.
    seed { doc test_doc }

    results = db.search("hello")

    assert_equal(1, results.size)
    assert_equal(1, results.first.score)
  end

  def test_size
    # An empty db has two empty arrays taking up 4 bytes.
    assert_equal 4, db.size
  end

  def test_empty
    seed do
      urls 3
      docs 2
    end

    assert_equal 5, db.empty
    assert_equal 0, (db.urls.size + db.docs.size)
  end
end
