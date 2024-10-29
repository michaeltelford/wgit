require_relative "helpers/test_helper"

# Test class for testing the Indexer methods.
# WARNING: The DB is cleared down prior to each test run.
class TestIndexer < TestHelper
  include MongoDBHelper

  # Runs before every test.
  def setup
    empty_db

    @indexer = Wgit::Indexer.new(db)
  end

  # Runs after every test.
  def teardown
    ENV[Wgit::Indexer::WGIT_IGNORE_ROBOTS_TXT] = nil
  end

  def test_initialize
    indexer = Wgit::Indexer.new

    assert_instance_of Wgit::Indexer,  indexer
    assert_instance_of Wgit::Crawler,  indexer.crawler
    assert_instance_of Wgit::Database::MongoDB, indexer.db

    refute_equal db, indexer.db
  end

  def test_initialize__with_database
    indexer = Wgit::Indexer.new db

    assert_instance_of Wgit::Indexer,  indexer
    assert_instance_of Wgit::Crawler,  indexer.crawler
    assert_instance_of Wgit::Database::MongoDB, indexer.db

    assert_equal db, indexer.db
  end

  def test_initialize__with_database_and_crawler
    crawler = Wgit::Crawler.new
    indexer = Wgit::Indexer.new db, crawler

    assert_instance_of Wgit::Indexer,  indexer
    assert_instance_of Wgit::Crawler,  indexer.crawler
    assert_instance_of Wgit::Database::MongoDB, indexer.db

    assert_equal crawler, indexer.crawler
    assert_equal db, indexer.db
  end

  def test_index_www__one_site
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"
    seed { url(url) }

    # Index only one site.
    @indexer.index_www max_sites: 1

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    # The orig url and its doc plus an external url.
    assert_equal 2, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_www__one_site__define_extractor
    Wgit::Document.define_extractor(
      :aside, "//aside", singleton: false, text_content_only: true
    )

    url = Wgit::Url.new "https://motherfuckingwebsite.com/"
    seed { url(url) }

    # Index only one site.
    @indexer.index_www max_sites: 1

    # Assert that the indexed document contains our extracted content.
    assert doc?(aside: "And it's fucking perfect.")

    # Remove the defined extractor to avoid interfering with other tests.
    Wgit::Document.remove_extractor(:aside)
    Wgit::Document.send(:remove_method, :aside)
  end

  def test_index_www__two_sites
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"
    seed { url(url) }

    # Index two sites.
    @indexer.index_www max_sites: 2

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    assert_equal 7, db.num_urls
    assert_equal 9, db.num_docs
  end

  def test_index_www__several_sites
    url = Wgit::Url.new "https://external-link-portal.com"
    seed { url(url) }

    # Index https://external-link-portal.com plus it's 5 externally linked sites.
    @indexer.index_www max_urls_per_iteration: 2

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    # 7 urls == orig_url + 6 blank page urls + 1 redirect url from http -> https.
    assert_equal 7, db.num_urls
    assert_equal 6, db.num_docs
  end

  def test_index_www__redirects
    url = Wgit::Url.new "http://redirect.com/4"
    seed { url(url) }

    # Index http://redirect.com/4 which redirects through to 7 and yields a single page.
    @indexer.index_www max_sites: 1

    # Assert that url and its redirects all get indexed as crawled.
    assert url? url: "http://redirect.com/4", crawled: true
    assert url? url: "http://redirect.com/5", crawled: true
    assert url? url: "http://redirect.com/6", crawled: true
    assert url? url: "http://redirect.com/7", crawled: true

    # Assert that some indexed docs were inserted into the DB.
    assert_equal 4, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_www__max_data
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"
    seed { url(url) }

    # Index nothing because max_data is zero.
    @indexer.index_www(max_sites: -1, max_data: 0)

    # Assert nothing was indexed. The only DB record is the original url.
    assert url? url: url, crawled: false
    assert_equal 1, db.num_records
  end

  def test_index_www__robots_txt
    # Links to http://robots.txt.com which has no externals, so crawl 2 sites.
    url = Wgit::Url.new "http://link-to-robots-txt.com"
    seed { url(url) }

    @indexer.index_www

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    # The orig url and its doc plus an external url and pages.
    assert_equal 2, db.num_urls
    assert_equal 5, db.num_docs
    assert_equal(
      %w[
        http://link-to-robots-txt.com
        http://robots.txt.com
        http://robots.txt.com/about
        http://robots.txt.com/contact
        http://robots.txt.com/
      ],
      db.docs.map(&:url).map(&:to_s)
    )
  end

  def test_index_www__ignore_robots_txt
    ENV[Wgit::Indexer::WGIT_IGNORE_ROBOTS_TXT] = "true"

    # Links to http://robots.txt.com which has no externals, so crawl 2 sites.
    url = Wgit::Url.new "http://link-to-robots-txt.com"
    seed { url(url) }

    @indexer.index_www

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    # The orig url and its doc plus an external url and pages.
    assert_equal 2, db.num_urls
    assert_equal 8, db.num_docs
    assert_equal(
      %w[
        http://link-to-robots-txt.com
        http://robots.txt.com
        http://robots.txt.com/login
        http://robots.txt.com/pwreset
        http://robots.txt.com/account
        http://robots.txt.com/about
        http://robots.txt.com/contact
        http://robots.txt.com/
      ],
      db.docs.map(&:url).map(&:to_s)
    )
  end

  def test_index_www__robots_txt__disallow_all
    url = Wgit::Url.new "http://disallow-all.com"
    seed { url(url) }

    # Try to index the site which is illegal via robots.txt file.
    @indexer.index_www

    # Assert that url.crawled gets updated; we must set url.crawled = true to
    # avoid crawling it again in the future.
    assert url? url: url, crawled: true

    # Assert that no indexed docs were inserted into the DB.
    assert_equal 1, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_index_site__without_externals
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"

    refute url? url: url

    # Index the site and don't insert the external urls.
    @indexer.index_site url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_site__with_externals
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"
    num_pages_crawled = 0

    refute url? url: url

    # Index the site and insert the external urls.
    @indexer.index_site url, insert_externals: true do |doc|
      assert_instance_of Wgit::Document, doc
      num_pages_crawled += 1
      true # To insert the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url and one external url.
    assert_equal 2, db.num_urls
    assert_equal 1, db.num_docs
    assert_equal 1, num_pages_crawled
  end

  def test_index_site__no_doc_insert
    # Test that returning nil/false from the block prevents saving the doc to
    # the DB.
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"

    refute url? url: url

    # Index the site and don't insert the external urls.
    @indexer.index_site url do |doc|
      assert_instance_of Wgit::Document, doc
      :skip # To avoid inserting the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_index_site__invalid_url
    # Test that an invalid URL isn't indexed.
    url = Wgit::Url.new "http://doesnt_exist/"

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
    assert_equal 1, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_index_site__manipulate_doc
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"

    refute url? url: url

    # Index the page and change the title before saving to DB.
    @indexer.index_site url do |doc|
      doc.title = "Boomskies!"
      true # Index the page.
    end

    # Assert that doc.title gets updated.
    assert doc? title: "Boomskies!"
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_site__redirects
    url = Wgit::Url.new "http://redirect.com/4"

    refute url? url: url

    # Index the site and don't insert the external urls.
    @indexer.index_site url, insert_externals: false

    # Assert that url and its redirects all get indexed as crawled.
    assert_equal "http://redirect.com/7", url.to_s
    assert url? url: "http://redirect.com/4", crawled: true
    assert url? url: "http://redirect.com/5", crawled: true
    assert url? url: "http://redirect.com/6", crawled: true
    assert url? url: "http://redirect.com/7", crawled: true

    # Assert that some indexed docs were inserted into the DB.
    assert_equal 4, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_site__robots_txt
    url = Wgit::Url.new "http://robots.txt.com"

    refute url? url: url

    # Index the site and don't insert the external urls.
    @indexer.index_site url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has 3 indexable docs plus its url.
    assert_equal 1, db.num_urls
    assert_equal 4, db.num_docs
    assert_equal(
      %w[
        http://robots.txt.com
        http://robots.txt.com/about
        http://robots.txt.com/contact
        http://robots.txt.com/
      ],
      db.docs.map(&:url).map(&:to_s)
    )
  end

  def test_index_site__ignore_robots_txt
    ENV[Wgit::Indexer::WGIT_IGNORE_ROBOTS_TXT] = "true"

    url = Wgit::Url.new "http://robots.txt.com"

    refute url? url: url

    # Index the site and don't insert the external urls.
    @indexer.index_site url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has 3 indexable docs, 1 ignored disallow plus its url.
    assert_equal 1, db.num_urls
    assert_equal 7, db.num_docs
    assert_equal(
      %w[
        http://robots.txt.com
        http://robots.txt.com/login
        http://robots.txt.com/pwreset
        http://robots.txt.com/account
        http://robots.txt.com/about
        http://robots.txt.com/contact
        http://robots.txt.com/
      ],
      db.docs.map(&:url).map(&:to_s)
    )
  end

  def test_index_site__robots_txt__disallow_all
    url = Wgit::Url.new "http://disallow-all.com"

    refute url? url: url

    # Try to index the site which is illegal via robots.txt file.
    @indexer.index_site url

    # Assert that url.crawled gets updated; we must set url.crawled = true to
    # avoid crawling it again in the future.
    assert url? url: url, crawled: true

    # The site has 2 docs plus its url but only the url is indexed/saved to the DB.
    assert_equal 1, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_index_urls__one_url
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"

    # Index one URL.
    @indexer.index_urls url, insert_externals: true

    # The site has one doc plus its url and one external url.
    assert_equal 2, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_urls__two_urls
    url  = Wgit::Url.new "https://motherfuckingwebsite.com/"
    url2 = Wgit::Url.new "http://txti.es"

    # Index two URLs.
    @indexer.index_urls url, url2

    # url points to url2 and url2 has no externals, totalling 2 urls and docs.
    assert_equal 2, db.num_urls
    assert_equal 2, db.num_docs
    assert_empty db.uncrawled_urls
  end

  def test_index_urls__redirects
    url  = Wgit::Url.new "http://redirect.com/4"
    url2 = Wgit::Url.new "https://motherfuckingwebsite.com/"

    # Index the site and don't insert the external urls.
    @indexer.index_urls url, url2

    # Assert that url and its redirects all get indexed as crawled.
    assert_equal "http://redirect.com/7", url.to_s
    assert url? url: "http://redirect.com/4", crawled: true
    assert url? url: "http://redirect.com/5", crawled: true
    assert url? url: "http://redirect.com/6", crawled: true
    assert url? url: "http://redirect.com/7", crawled: true
    assert url? url: "https://motherfuckingwebsite.com/", crawled: true

    # Assert that some indexed docs were inserted into the DB.
    assert_equal 5, db.num_urls
    assert_equal 2, db.num_docs
    assert_empty db.uncrawled_urls
  end

  def test_index_urls__manipulate_doc
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"

    refute url? url: url

    # Index the page and change the title before saving to DB.
    @indexer.index_urls url do |doc|
      doc.title = "Boomskies!"
      true # Index the page.
    end

    # Assert that doc.title gets updated.
    assert doc? title: "Boomskies!"
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_urls__robots_txt_and_no_index
    urls = %w[
      http://robots.txt.com/login
      http://disallow-all.com
      http://robots.txt.com/pwreset
      http://robots.txt.com/account
    ].to_urls

    # Index several URLs, not inserting the external urls found.
    @indexer.index_urls(*urls)

    assert_equal 4, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_index_urls__ignore_robots_txt
    ENV[Wgit::Indexer::WGIT_IGNORE_ROBOTS_TXT] = "true"

    urls = %w[
      http://robots.txt.com/login
      http://disallow-all.com
      http://robots.txt.com/pwreset
      http://robots.txt.com/account
    ].to_urls

    # Index several URLs, not inserting the external urls found.
    @indexer.index_urls(*urls)

    assert_equal 4, db.num_urls
    assert_equal 4, db.num_docs
  end

  def test_index_url__without_externals
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"

    refute url? url: url

    # Index the page and don't insert the external urls.
    @indexer.index_url url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_url__with_externals
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"

    refute url? url: url

    # Index the page and insert the external urls.
    @indexer.index_url url, insert_externals: true

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url and one external url.
    assert_equal 2, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_url__no_doc_insert
    # Test that returning nil/false from the block prevents saving the doc to
    # the DB.
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"

    refute url? url: url

    # Index the page and don't insert the external urls.
    @indexer.index_url url do |doc|
      assert_instance_of Wgit::Document, doc
      :skip # To avoid inserting the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_index_url__invalid_url
    # Test that an invalid URL isn't indexed.
    url = Wgit::Url.new "http://doesnt_exist/"

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
    assert_equal 1, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_index_url__manipulate_doc
    url = Wgit::Url.new "https://motherfuckingwebsite.com/"

    refute url? url: url

    # Index the page and change the title before saving to DB.
    @indexer.index_url url do |doc|
      doc.title = "Boomskies!"
      true # Index the page.
    end

    # Assert that doc.title gets updated.
    assert doc? title: "Boomskies!"
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_url__upsert
    # Test that re-indexing updates to the new content.
    # All index_* methods use #upsert_doc so there's no need to test them all.

    # 1st index returns 'Original content', 2nd: 'Updated content'.
    url = "http://www.content-updates.com".to_url

    @indexer.index_url url
    assert_equal 1, @indexer.db.search("Original").size
    assert_equal 0, @indexer.db.search("Updated").size

    @indexer.index_url url
    assert_equal 0, @indexer.db.search("Original").size
    assert_equal 1, @indexer.db.search("Updated").size
    assert_equal 1, @indexer.db.num_docs
  end

  def test_index_url__single_redirect
    url = Wgit::Url.new "http://redirect.com/6"

    refute url? url: url

    # Index the page and don't insert the external urls.
    @indexer.index_url url

    # Assert that url and its single redirect get indexed as crawled.
    assert_equal "http://redirect.com/7", url.to_s

    assert url? url: "http://redirect.com/6", crawled: true
    assert url? url: "http://redirect.com/7", crawled: true

    # Assert that some indexed docs were inserted into the DB.
    assert_equal 2, db.num_urls
    assert_equal 1, db.num_docs
    assert_empty db.uncrawled_urls
  end

  def test_index_url__several_redirects
    url = Wgit::Url.new "http://redirect.com/4"

    refute url? url: url

    # Index the page and don't insert the external urls.
    @indexer.index_url url

    # Assert that url and its redirects all get indexed as crawled.
    assert_equal "http://redirect.com/7", url.to_s

    assert url? url: "http://redirect.com/4", crawled: true
    assert url? url: "http://redirect.com/5", crawled: true
    assert url? url: "http://redirect.com/6", crawled: true
    assert url? url: "http://redirect.com/7", crawled: true

    # Assert that some indexed docs were inserted into the DB.
    assert_equal 4, db.num_urls
    assert_equal 1, db.num_docs
    assert_empty db.uncrawled_urls
  end

  def test_index_url__robots_txt
    # /login is disallowed by robots.txt file.
    url = Wgit::Url.new "http://robots.txt.com/login"

    refute url? url: url

    # Index the url and don't insert the external urls.
    @indexer.index_url url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    assert_equal 1, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_index_url__ignore_robots_txt
    ENV[Wgit::Indexer::WGIT_IGNORE_ROBOTS_TXT] = "true"

    # /login is disallowed by robots.txt file.
    url = Wgit::Url.new "http://robots.txt.com/login"

    refute url? url: url

    # Index the url and don't insert the external urls.
    @indexer.index_url url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    assert_equal 1, db.num_urls
    assert_equal 1, db.num_docs
  end

  def test_index_url__robots_txt__disallow_all
    url = Wgit::Url.new "http://disallow-all.com"

    refute url? url: url

    # Index the url and don't insert the external urls.
    @indexer.index_url url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    assert_equal 1, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_index_url__no_index__html
    # /pwreset is disallowed by HTML meta tag.
    url = Wgit::Url.new "http://robots.txt.com/pwreset"

    refute url? url: url

    # Index the url and don't insert the external urls.
    @indexer.index_url url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    assert_equal 1, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_index_url__no_index__resp
    # /account is disallowed by HTTP response header.
    url = Wgit::Url.new "http://robots.txt.com/account"

    refute url? url: url

    # Index the url and don't insert the external urls.
    @indexer.index_url url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    assert_equal 1, db.num_urls
    assert_equal 0, db.num_docs
  end

  def test_merge_paths__no_parser_rules
    allow, disallow = @indexer.send(:merge_paths, nil, nil, nil)
    assert_nil allow
    assert_nil disallow

    parser = Wgit::RobotsParser.new ""
    allow, disallow = @indexer.send(:merge_paths, parser, nil, nil)
    assert_nil allow
    assert_nil disallow

    allow, disallow = @indexer.send(:merge_paths, nil, [], [])
    assert_empty allow
    assert_empty disallow
  end

  def test_merge_paths__paths_array
    parser = Wgit::RobotsParser.new <<~TEXT
      User-agent: wgit
      Allow: /about
      Allow: /about2
      Disallow: /login
      Disallow: /login2
    TEXT
    allow, disallow = @indexer.send(
      :merge_paths, parser, %w[/contact /contact2], %w[/passreset /passreset2]
    )

    assert_equal %w[/contact /contact2 /about /about2], allow
    assert_equal %w[/passreset /passreset2 /login /login2], disallow
  end

  def test_merge_paths__single_path_string
    parser = Wgit::RobotsParser.new <<~TEXT
      User-agent: wgit
      Allow: /about
      Disallow: /login
    TEXT
    allow, disallow = @indexer.send(:merge_paths, parser, "/contact", "/passreset")

    assert_equal %w[/contact /about], allow
    assert_equal %w[/passreset /login], disallow
  end
end
