require_relative "helpers/test_helper"

# Test class for testing the DSL methods.
# WARNING: Certain tests will clear down the DB prior to the test run.
class TestDSL < TestHelper
  include MongoDBHelper
  include Wgit::DSL

  # Runs before every test.
  def setup
    @dsl_crawler = nil
    @dsl_start   = nil
    @dsl_follow  = nil
    @dsl_db      = nil
  end

  ### CRAWLER METHOD TESTS ###

  def test_extract
    refute Wgit::Document.extractors.include? :blah

    opts = { singleton: false, text_content_only: false }
    extract(:blah, "//blah", opts) { |blah| blah }

    assert Wgit::Document.extractors.include? :blah

    # Clean up the extractor for other tests.
    Wgit::Document.remove_extractor :blah
  end

  def test_use_crawler
    crawler = use_crawler { |c| c.redirect_limit = 10 }

    assert_instance_of Wgit::Crawler, @dsl_crawler
    assert_equal @dsl_crawler.object_id, crawler.object_id
    assert_equal 10, crawler.redirect_limit
    assert_equal crawler.object_id, crawler.object_id
  end

  def test_start
    start "http://example.com" do |crawler|
      crawler.timeout = 10
    end

    assert_equal ["http://example.com"], @dsl_start
    assert_equal 10, use_crawler.timeout
  end

  def test_start__several_urls
    start "http://example.com", "http://txti.es/" do |crawler|
      crawler.timeout = 10
    end

    assert_equal ["http://example.com", "http://txti.es/"], @dsl_start
    assert_equal 10, use_crawler.timeout
  end

  def test_follow
    follow "//a/@href"

    assert_equal "//a/@href", @dsl_follow
  end

  def test_crawl__no_url
    ex = assert_raises(StandardError) { crawl }

    assert_equal DSL_ERROR__NO_START_URL, ex.message
  end

  def test_crawl__start_url
    start "https://search.yahoo.com"
    doc = crawl

    assert_equal "https://search.yahoo.com", doc.url
  end

  def test_crawl__several_urls
    # Shouldn't be used because of the urls param.
    start "http://example.com/doesntexist"

    urls = []
    crawl "https://search.yahoo.com", "http://twitter.com" do |doc|
      urls << doc.url
    end

    assert_equal %w[https://search.yahoo.com https://twitter.com], urls
  end

  def test_crawl__start__several_urls
    start "https://search.yahoo.com", "http://twitter.com"

    urls = []
    crawl { |doc| urls << doc.url }

    assert_equal %w[https://search.yahoo.com https://twitter.com], urls
  end

  def test_crawl__single_url__no_redirects
    # An empty doc is returned because of the redirect from http -> https.
    doc = crawl("http://twitter.com", follow_redirects: false)
    assert doc.empty?
  end

  def test_crawl_site__no_url
    ex = assert_raises(StandardError) { crawl_site }

    assert_equal DSL_ERROR__NO_START_URL, ex.message
  end

  def test_crawl_site__start_url
    start "http://txti.es/"
    crawl_site do |doc|
      assert_equal "http://txti.es/", doc.url
      break # Don't bother crawling the entire site.
    end
  end

  def test_crawl_site__url_param
    # Shouldn't be used because of the url param.
    start "http://example.com/doesntexist"

    crawl_site("http://txti.es/") do |doc|
      assert_equal "http://txti.es/", doc.url
      break # Don't bother crawling the entire site.
    end
  end

  def test_crawl_site__allow_paths
    urls = []
    start "http://txti.es/"
    crawl_site(allow_paths: "images") { |doc| urls << doc.url }

    assert urls.include? "http://txti.es/"
    urls.delete "http://txti.es/"
    assert(urls.all? { |url| url.include? "images" })
  end

  def test_crawl_site__disallow_paths
    urls = []
    start "http://txti.es/"
    crawl_site(disallow_paths: "images") { |doc| urls << doc.url }

    assert urls.include? "http://txti.es/"
    urls.delete "http://txti.es/"
    assert(urls.none? { |url| url.include? "images" })
  end

  def test_crawl_site__several_urls
    # Shouldn't be used because of the urls param.
    start "http://twitter.com"

    urls = []
    externals = crawl_site "http://txti.es/", "http://test-site.com" do |doc|
      urls << doc.url
    end

    assert_equal 17, urls.size
    refute urls.include?("http://twitter.com")
    assert urls.include?("http://txti.es/")
    assert urls.include?("http://test-site.com")
    assert urls.include?("http://test-site.com/")
    assert externals.include?("http://twitter.com/txties")
    assert externals.include?("http://ftp.test-site.com")
  end

  def test_crawl_site__start__several_urls
    start "http://txti.es/", "http://test-site.com"

    urls = []
    externals = crawl_site { |doc| urls << doc.url }

    assert_equal 17, urls.size
    assert urls.include?("http://txti.es/")
    assert urls.include?("http://test-site.com")
    assert urls.include?("http://test-site.com/")
    assert externals.include?("http://twitter.com/txties")
    assert externals.include?("http://ftp.test-site.com")
  end

  def test_last_response
    crawl "http://www.belfastpilates.co.uk"
    assert_instance_of Wgit::Response, last_response
  end

  def test_reset
    use_database true # Just to test nilification below.
    follow "//a"
    start("http://example.com") { |c| c.timeout = 5 }

    reset

    assert_nil @dsl_crawler
    assert_nil @dsl_start
    assert_nil @dsl_follow
    assert_nil @dsl_db
  end

  ### INDEXER METHOD TESTS ###

  def test_use_database
    use_database true # Just to test var value below.

    assert @dsl_db
  end

  def test_index_www__max_sites
    empty_db
    seed do
      url "http://txti.es/"
      url "http://test-site.com"
    end

    index_www max_sites: 1

    assert doc?("url.url" => "http://txti.es/")
    refute doc?("url.url" => "http://test-site.com")
  end

  def test_index_www__max_data
    empty_db
    seed do
      url "http://txti.es/"
      url "http://test-site.com"
    end

    use_database Wgit::Database::MongoDB.new
    # max_data: 1KB should only allow the crawl of the first site.
    index_www max_data: 1000

    assert doc?("url.url" => "http://txti.es/")
    refute doc?("url.url" => "http://test-site.com")
  end

  def test_index_site__no_url
    ex = assert_raises(StandardError) { index_site }

    assert_equal DSL_ERROR__NO_START_URL, ex.message
  end

  def test_index_site__start_url
    empty_db

    start "http://txti.es/"
    use_database Wgit::Database::MongoDB.new
    index_site insert_externals: true

    assert doc?("url.url" => "http://txti.es/")
    assert_equal 7, db.num_docs
    assert_equal 6, db.num_urls
  end

  def test_index_site__url_param
    empty_db

    # Shouldn't be used because of the url param.
    start "http://example.com/doesntexist"

    index_site "http://txti.es/" do |doc|
      # Dont save the index page to the DB.
      :skip if doc.url == "http://txti.es/"
    end

    refute doc?("url.url" => "http://txti.es/")
    assert_equal 6, db.num_docs
    assert_equal 1, db.num_urls
  end

  def test_index_site__allow_paths
    empty_db

    index_site "http://txti.es/", allow_paths: "about"

    assert doc?("url.url" => "http://txti.es/")
    assert_equal 2, db.num_docs
  end

  def test_index_site__disallow_paths
    empty_db

    index_site "http://txti.es/", disallow_paths: "images"

    assert doc?("url.url" => "http://txti.es/")
    assert_equal 5, db.num_docs
  end

  def test_index__no_url
    ex = assert_raises(StandardError) { index }

    assert_equal DSL_ERROR__NO_START_URL, ex.message
  end

  def test_index__start_url
    empty_db

    start "http://txti.es/"
    use_database Wgit::Database::MongoDB.new
    index

    assert doc?("url.url" => "http://txti.es/")
    assert_equal 1, db.num_docs
    assert_equal 1, db.num_urls
  end

  def test_index__single_url
    empty_db

    # Dont save the page to the DB.
    index("http://txti.es/") { :skip }

    refute doc?("url.url" => "http://txti.es/")
    assert_equal 0, db.num_docs
    assert_equal 1, db.num_urls
  end

  def test_index__several_urls
    empty_db

    # Shouldn't be used because of the urls param.
    start "http://example.com/doesntexist"

    # Dont save the page to the DB.
    urls = []
    index("http://txti.es/", "http://test-site.com", insert_externals: true) do |doc|
      urls << doc.url
    end

    assert_equal ["http://txti.es/", "http://test-site.com"], urls
    assert doc?("url.url" => "http://txti.es/")
    assert doc?("url.url" => "http://test-site.com")
    assert_equal 2, db.num_docs
    assert_equal 4, db.num_urls
  end

  def test_index_site__several_urls
    empty_db

    # Shouldn't be used because of the urls param.
    start "http://twitter.com"

    urls = []
    count = index_site "http://txti.es/", "http://test-site.com" do |doc|
      urls << doc.url
      true # Index the page.
    end

    assert_equal 17, urls.size
    assert_equal 14, count # 4 urls are invalid/external redirects.
    refute urls.include?("http://twitter.com")
    assert urls.include?("http://txti.es/")
    assert urls.include?("http://test-site.com")
    assert urls.include?("http://test-site.com/")
  end

  def test_index_site__start__several_urls
    empty_db

    start "http://txti.es/", "http://test-site.com"

    urls = []
    count = index_site do |doc|
      urls << doc.url
      true # Index the page.
    end

    assert_equal 17, urls.size
    assert_equal 14, count # 4 urls are invalid/external redirects.
    assert urls.include?("http://txti.es/")
    assert urls.include?("http://test-site.com")
    assert urls.include?("http://test-site.com/")
  end

  def test_search
    empty_db

    test_doc = Wgit::Document.new(DatabaseTestData.doc)
    seed { doc test_doc }

    count = 0
    results = search("Route", stream: nil) do |doc|
      assert_instance_of Wgit::Document, doc
      assert doc.text.include?("Route")

      count += 1
    end

    assert_equal 1, count
    assert_equal 1, results.size
    assert_instance_of Wgit::Document, results.first
    assert results.first.text.include?("Route")
  end

  def test_search__all_params
    results = search("noop", stream: nil, case_sensitive: true,
      whole_sentence: false, limit: 3, skip: 3, sentence_limit: 100)

    assert_empty results
  end

  def test_empty_db!
    empty_db # From MongoDBHelper.
    seed { url(2) }

    empty_db! # From DSL.

    assert_equal 0, db.size
  end
end
