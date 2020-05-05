require_relative 'helpers/test_helper'

# Test class for testing the DSL methods.
# WARNING: Certain tests will clear down the DB prior to the test run.
class TestDSL < TestHelper
  include DatabaseHelper
  include Wgit::DSL

  # Runs before every test.
  def setup
    @dsl_url      = nil
    @dsl_conn_str = nil
  end

  ### CRAWLER METHOD TESTS ###

  def test_extract
    refute Wgit::Document.extensions.include? :blah

    opts = { singleton: false, text_content_only: false }
    extract(:blah, '//blah', opts) { |blah| blah }

    assert Wgit::Document.extensions.include? :blah

    # Clean up the extractor for other tests.
    Wgit::Document.remove_extension :blah
  end

  def test_crawler
    crawler { |c| c.redirect_limit = 10 }

    assert_instance_of Wgit::Crawler, @dsl_crawler
    assert_equal @dsl_crawler.object_id, crawler.object_id
    assert_equal 10, crawler.redirect_limit
  end

  def test_start
    start 'http://example.com' do |crawler|
      crawler.time_out = 10
    end

    assert_equal 'http://example.com', @dsl_url
    assert_equal 10, crawler.time_out
  end

  def test_follow
    follow('//a/@href') do |links, doc, type|
      assert_instance_of Wgit::Document, doc
      assert_equal :document, type

      links + [Wgit::Url.new('http://www.foobar.com/about')]
    end

    doc = Wgit::Document.new 'http://www.example.com', <<~HTML
      <html>
        <a href="/contact">Valid link</a>
        <a href="http://">Invalid link</a>
      </html>
    HTML
    expected_next_urls = [
      'http://www.example.com/contact',
      'http://www.foobar.com/about'
    ]

    assert Wgit::Document.extensions.include? :dsl_next_urls
    assert crawler.respond_to? :next_urls
    assert_equal expected_next_urls, doc.dsl_next_urls
    assert_equal expected_next_urls, crawler.next_urls(doc)
    assert doc.dsl_next_urls.all? { |url| url.is_a? Wgit::Url }

    # Clean up the extractor for other tests.
    Wgit::Document.remove_extension :dsl_next_urls
    Wgit::Document.send(:remove_method, :dsl_next_urls)
  end

  def test_crawl__no_url
    ex = assert_raises(StandardError) { crawl }

    assert_equal DSL_ERROR__NO_START_URL, ex.message
  end

  def test_crawl__start_url
    start 'https://duckduckgo.com'
    doc = crawl

    assert_equal 'https://duckduckgo.com', doc.url
  end

  def test_crawl__several_urls
    urls = []
    crawl 'https://duckduckgo.com', 'http://twitter.com' do |doc|
      urls << doc.url
    end

    assert_equal %w[https://duckduckgo.com https://twitter.com], urls
  end

  def test_crawl__single_url__no_redirects
    # Nil should return because of the redirect from http -> https.
    assert_nil crawl('http://twitter.com', follow_redirects: false)
  end

  def test_crawl_site__no_url
    ex = assert_raises(StandardError) { crawl_site }

    assert_equal DSL_ERROR__NO_START_URL, ex.message
  end

  def test_crawl_site__start_url
    start 'http://txti.es/'
    crawl_site do |doc|
      assert_equal 'http://txti.es/', doc.url
      break # Don't bother crawling the entire site.
    end
  end

  def test_crawl_site__url_param
    crawl_site('http://txti.es/') do |doc|
      assert_equal 'http://txti.es/', doc.url
      break # Don't bother crawling the entire site.
    end
  end

  def test_crawl_site__allow_paths
    urls = []
    start 'http://txti.es/'
    crawl_site(allow_paths: 'images') { |doc| urls << doc.url }

    assert urls.include? 'http://txti.es/'
    urls.delete 'http://txti.es/'
    assert urls.all? { |url| url.include? 'images' }
  end

  def test_crawl_site__disallow_paths
    urls = []
    start 'http://txti.es/'
    crawl_site(disallow_paths: 'images') { |doc| urls << doc.url }

    assert urls.include? 'http://txti.es/'
    urls.delete 'http://txti.es/'
    assert urls.none? { |url| url.include? 'images' }
  end

  def test_last_response
    crawl 'http://www.belfastpilates.co.uk'
    assert_instance_of Wgit::Response, last_response
  end

  ### INDEXER METHOD TESTS ###

  def test_connection_string
    connection_string 'mongodb://myprimary.com:27017'

    assert_equal 'mongodb://myprimary.com:27017', @dsl_conn_str
  end

  def test_index_www__max_sites
    clear_db
    seed do
      url 'http://txti.es/'
      url 'http://test-site.com'
    end

    index_www max_sites: 1

    assert doc?('url.url' => 'http://txti.es/')
    refute doc?('url.url' => 'http://test-site.com')
  end

  def test_index_www__max_data
    clear_db
    seed do
      url 'http://txti.es/'
      url 'http://test-site.com'
    end

    # max_data: 1KB should only allow the crawl of the first site.
    index_www connection_string: ENV['WGIT_CONNECTION_STRING'], max_data: 1000

    assert doc?('url.url' => 'http://txti.es/')
    refute doc?('url.url' => 'http://test-site.com')
  end

  def test_index_site__no_url
    ex = assert_raises(StandardError) { index_site }

    assert_equal DSL_ERROR__NO_START_URL, ex.message
  end

  def test_index_site__start_url
    clear_db

    start 'http://txti.es/'
    index_site connection_string: ENV['WGIT_CONNECTION_STRING'], insert_externals: false

    assert doc?('url.url' => 'http://txti.es/')
    assert_equal 7, database.num_docs
    assert_equal 1, database.num_urls
  end

  def test_index_site__url_param
    clear_db

    index_site 'http://txti.es/' do |doc|
      # Dont save the index page to the DB.
      doc.url == 'http://txti.es/' ? false : true
    end

    refute doc?('url.url' => 'http://txti.es/')
    assert_equal 6, database.num_docs
    assert_equal 8, database.num_urls
  end

  def test_index_site__allow_paths
    clear_db

    index_site 'http://txti.es/', allow_paths: 'about'

    assert doc?('url.url' => 'http://txti.es/')
    assert_equal 2, database.num_docs
  end

  def test_index_site__disallow_paths
    clear_db

    index_site 'http://txti.es/', disallow_paths: 'images'

    assert doc?('url.url' => 'http://txti.es/')
    assert_equal 5, database.num_docs
  end

  def test_index__no_url
    ex = assert_raises(StandardError) { index }

    assert_equal DSL_ERROR__NO_START_URL, ex.message
  end

  def test_index__start_url
    clear_db

    start 'http://txti.es/'
    index connection_string: ENV['WGIT_CONNECTION_STRING'], insert_externals: false

    assert doc?('url.url' => 'http://txti.es/')
    assert_equal 1, database.num_docs
    assert_equal 1, database.num_urls
  end

  def test_index__single_url
    clear_db

    # Dont save the page to the DB.
    index('http://txti.es/') { false }

    refute doc?('url.url' => 'http://txti.es/')
    assert_equal 0, database.num_docs
    assert_equal 1, database.num_urls
  end

  def test_index__several_urls
    clear_db

    # Dont save the page to the DB.
    urls = []
    index('http://txti.es/', 'http://test-site.com') do |doc|
      urls << doc.url
    end

    assert_equal ['http://txti.es/', 'http://test-site.com'], urls
    assert doc?('url.url' => 'http://txti.es/')
    assert doc?('url.url' => 'http://test-site.com')
    assert_equal 2, database.num_docs
    assert_equal 4, database.num_urls
  end

  def test_search
    clear_db
    count = 0

    results = search('noop', stream: nil) { count += 1 }

    assert_equal 0, count
    assert_empty results
  end

  def test_search__connection_string
    clear_db

    connection_string ENV['WGIT_CONNECTION_STRING']
    results = search('noop', stream: nil)

    assert_empty results
  end

  def test_search__all_params
    results = search('noop', connection_string: ENV['WGIT_CONNECTION_STRING'],
      stream: nil, case_sensitive: true, whole_sentence: false,
      limit: 3, skip: 3, sentence_limit: 100)

    assert_empty results
  end

  def test_clear_db!
    clear_db
    seed { url(2) }

    clear_db!

    assert_equal 0, database.size
  end
end
