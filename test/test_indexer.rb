require_relative 'helpers/test_helper'

# Test class for testing the Indexer methods.
# WARNING: The DB is cleared down prior to each test run.
class TestIndexer < TestHelper
  include Wgit::DatabaseHelper

  # Runs before every test.
  def setup
    clear_db

    @db = Wgit::Database.new
  end

  def test_initialize
    indexer = Wgit::Indexer.new @db

    assert_instance_of Wgit::Indexer,  indexer
    assert_instance_of Wgit::Crawler,  indexer.crawler
    assert_instance_of Wgit::Database, indexer.db

    assert_equal @db, indexer.db
  end

  def test_initialize__with_crawler
    crawler = Wgit::Crawler.new
    indexer = Wgit::Indexer.new @db, crawler

    assert_instance_of Wgit::Indexer,  indexer
    assert_instance_of Wgit::Crawler,  indexer.crawler
    assert_instance_of Wgit::Database, indexer.db

    assert_equal @db,     indexer.db
    assert_equal crawler, indexer.crawler
  end

  def test_index_www__one_site
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    seed { url(url) }

    # Index only one site.
    Wgit.index_www connection_string: ENV['WGIT_CONNECTION_STRING'], max_sites: 1

    # Assert that url.crawled gets updated.
    refute url? url: url, crawled: false
    assert url? url: url, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    # The orig url and its doc plus an external url.
    assert_equal 2, @db.num_urls
    assert_equal 1, @db.num_docs
  end

  def test_index_www__one_site__define_extension
    Wgit::Document.define_extension(
      :aside, '//aside', singleton: false, text_content_only: true
    )

    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    seed { url(url) }

    # Index only one site.
    Wgit.index_www connection_string: ENV['WGIT_CONNECTION_STRING'], max_sites: 1

    # Assert that the indexed document contains our extension data.
    assert doc?(aside: "And it's fucking perfect.")

    # Remove the defined extension to avoid interfering with other tests.
    Wgit::Document.remove_extension(:aside)
    Wgit::Document.send(:remove_method, :aside)
  end

  def test_index_www__two_sites
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    seed { url(url) }

    # Index two sites.
    Wgit.index_www max_sites: 2

    # Assert that url.crawled gets updated.
    refute url? url: url, crawled: false
    assert url? url: url, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    assert_equal 9, @db.num_urls
    assert_equal 8, @db.num_docs
  end

  def test_index_www__max_data
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    seed { url(url) }

    # Index nothing because max_data is zero.
    Wgit.index_www(max_sites: -1, max_data: 0)

    # Assert nothing was indexed. The only DB record is the original url.
    refute url? url: url, crawled: true
    assert url? url: url, crawled: false
    assert_equal 1, @db.num_records
  end

  def test_index_site__without_externals
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the site and don't insert the external urls.
    Wgit.index_site url, connection_string: ENV['WGIT_CONNECTION_STRING'], insert_externals: false

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, @db.num_urls
    assert_equal 1, @db.num_docs
  end

  def test_index_site__with_externals
    url = 'https://motherfuckingwebsite.com/'
    num_pages_crawled = 0

    refute url? url: url

    # Index the site and don't insert the external urls.
    Wgit.index_site url do |doc|
      assert_instance_of Wgit::Document, doc
      num_pages_crawled += 1
      true # To insert the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url and one external url.
    assert_equal 2, @db.num_urls
    assert_equal 1, @db.num_docs
    assert_equal 1, num_pages_crawled
  end

  def test_index_site__no_doc_insert
    # Test that returning nil/false from the block prevents saving the doc to
    # the DB.
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the site and don't insert the external urls.
    Wgit.index_site url, insert_externals: false do |doc|
      assert_instance_of Wgit::Document, doc
      false # To avoid inserting the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, @db.num_urls
    assert_equal 0, @db.num_docs
  end

  def test_index_site__invalid_url
    # Test that an invalid URL isn't indexed.
    url = Wgit::Url.new 'http://doesnt_exist/'

    refute url? url: url

    # Index the site and insert the external urls.
    Wgit.index_site url do |doc|
      assert_equal url, doc.url
      assert_empty doc
      true # Try to insert the crawled page (but shouldn't because it's nil).
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The url's doc wasn't indexed because it's nil due to an invalid url.
    assert_equal 1, @db.num_urls
    assert_equal 0, @db.num_docs
  end

  def test_index_page__without_externals
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the page and don't insert the external urls.
    Wgit.index_page url, connection_string: ENV['WGIT_CONNECTION_STRING'], insert_externals: false

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, @db.num_urls
    assert_equal 1, @db.num_docs
  end

  def test_index_page__with_externals
    url = 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the page and insert the external urls.
    Wgit.index_page url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url and one external url.
    assert_equal 2, @db.num_urls
    assert_equal 1, @db.num_docs
  end

  def test_index_page__no_doc_insert
    # Test that returning nil/false from the block prevents saving the doc to
    # the DB.
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the page and don't insert the external urls.
    Wgit.index_page url, insert_externals: false do |doc|
      assert_instance_of Wgit::Document, doc
      false # To avoid inserting the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, @db.num_urls
    assert_equal 0, @db.num_docs
  end

  def test_index_page__invalid_url
    # Test that an invalid URL isn't indexed.
    url = Wgit::Url.new 'http://doesnt_exist/'

    refute url? url: url

    # Index the page and insert the external urls.
    Wgit.index_page url do |doc|
      assert_equal url, doc.url
      assert_empty doc
      true # Try to insert the crawled page (but shouldn't because it's nil).
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, @db.num_urls
    assert_equal 0, @db.num_docs
  end

  def test_indexed_search
    # Because this is a convienence method, the search and format have been
    # tested in Database, Document & Utils; so we just refute an error.
    assert_nil Wgit.indexed_search 'abcdefghijklmnopqrstuvwxyz'
  end
end
