require_relative 'helpers/test_helper'

# Test class for testing the Indexer methods.
# WARNING: The DB is cleared down prior to each test run.
class TestIndexer < TestHelper
  include DatabaseHelper

  # Runs before every test.
  def setup
    clear_db

    @indexer = Wgit::Indexer.new(database)
  end

  def test_initialize
    indexer = Wgit::Indexer.new database

    assert_instance_of Wgit::Indexer,  indexer
    assert_instance_of Wgit::Crawler,  indexer.crawler
    assert_instance_of Wgit::Database, indexer.db

    assert_equal database, indexer.db
  end

  def test_initialize__with_crawler
    crawler = Wgit::Crawler.new
    indexer = Wgit::Indexer.new database, crawler

    assert_instance_of Wgit::Indexer,  indexer
    assert_instance_of Wgit::Crawler,  indexer.crawler
    assert_instance_of Wgit::Database, indexer.db

    assert_equal database, indexer.db
    assert_equal crawler,  indexer.crawler
  end

  def test_index_www__one_site
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    seed { url(url) }

    # Index only one site.
    @indexer.index_www max_sites: 1

    # Assert that url.crawled gets updated.
    refute url? url: url, crawled: false
    assert url? url: url, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    # The orig url and its doc plus an external url.
    assert_equal 2, database.num_urls
    assert_equal 1, database.num_docs
  end

  def test_index_www__one_site__define_extension
    Wgit::Document.define_extension(
      :aside, '//aside', singleton: false, text_content_only: true
    )

    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    seed { url(url) }

    # Index only one site.
    @indexer.index_www max_sites: 1

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
    @indexer.index_www max_sites: 2

    # Assert that url.crawled gets updated.
    refute url? url: url, crawled: false
    assert url? url: url, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    assert_equal 9, database.num_urls
    assert_equal 8, database.num_docs
  end

  def test_index_www__max_data
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    seed { url(url) }

    # Index nothing because max_data is zero.
    @indexer.index_www(max_sites: -1, max_data: 0)

    # Assert nothing was indexed. The only DB record is the original url.
    refute url? url: url, crawled: true
    assert url? url: url, crawled: false
    assert_equal 1, database.num_records
  end

  def test_index_site__without_externals
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the site and don't insert the external urls.
    @indexer.index_site url, insert_externals: false

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, database.num_urls
    assert_equal 1, database.num_docs
  end

  def test_index_site__with_externals
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    num_pages_crawled = 0

    refute url? url: url

    # Index the site and don't insert the external urls.
    @indexer.index_site url do |doc|
      assert_instance_of Wgit::Document, doc
      num_pages_crawled += 1
      true # To insert the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url and one external url.
    assert_equal 2, database.num_urls
    assert_equal 1, database.num_docs
    assert_equal 1, num_pages_crawled
  end

  def test_index_site__no_doc_insert
    # Test that returning nil/false from the block prevents saving the doc to
    # the DB.
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the site and don't insert the external urls.
    @indexer.index_site url, insert_externals: false do |doc|
      assert_instance_of Wgit::Document, doc
      false # To avoid inserting the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, database.num_urls
    assert_equal 0, database.num_docs
  end

  def test_index_site__invalid_url
    # Test that an invalid URL isn't indexed.
    url = Wgit::Url.new 'http://doesnt_exist/'

    refute url? url: url

    # Index the site and insert the external urls.
    @indexer.index_site url do |doc|
      assert_equal url, doc.url
      assert_empty doc
      true # Try to insert the crawled page (but shouldn't because it's nil).
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The url's doc wasn't indexed because it's nil due to an invalid url.
    assert_equal 1, database.num_urls
    assert_equal 0, database.num_docs
  end

  def test_index_urls__one_url
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    # Index one URL.
    @indexer.index_urls url

    # The site has one doc plus its url and one external url.
    assert_equal 2, database.num_urls
    assert_equal 1, database.num_docs
  end

  def test_index_urls__two_urls
    url  = Wgit::Url.new 'https://motherfuckingwebsite.com/'
    url2 = Wgit::Url.new 'http://txti.es'

    # Index two URLs.
    @indexer.index_urls url, url2

    # url points to url2 and url2 has no externals, totalling 2 urls and docs.
    assert_equal 2, database.num_urls
    assert_equal 2, database.num_docs
    assert_empty database.uncrawled_urls
  end

  def test_index_url__without_externals
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the page and don't insert the external urls.
    @indexer.index_url url, insert_externals: false

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, database.num_urls
    assert_equal 1, database.num_docs
  end

  def test_index_url__with_externals
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the page and insert the external urls.
    @indexer.index_url url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url and one external url.
    assert_equal 2, database.num_urls
    assert_equal 1, database.num_docs
  end

  def test_index_url__no_doc_insert
    # Test that returning nil/false from the block prevents saving the doc to
    # the DB.
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the page and don't insert the external urls.
    @indexer.index_url url, insert_externals: false do |doc|
      assert_instance_of Wgit::Document, doc
      false # To avoid inserting the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, database.num_urls
    assert_equal 0, database.num_docs
  end

  def test_index_url__invalid_url
    # Test that an invalid URL isn't indexed.
    url = Wgit::Url.new 'http://doesnt_exist/'

    refute url? url: url

    # Index the page and insert the external urls.
    @indexer.index_url url do |doc|
      assert_equal url, doc.url
      assert_empty doc
      true # Try to insert the crawled page (but shouldn't because it's nil).
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, database.num_urls
    assert_equal 0, database.num_docs
  end
end
