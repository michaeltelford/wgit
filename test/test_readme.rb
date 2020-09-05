require_relative 'helpers/test_helper'

# Test class for code snippets in the README.md.
# WARNING: Certain tests will clear down the DB prior to the test run.
class TestReadme < TestHelper
  include Wgit::DSL

  # Runs before every test.
  def setup; end

  def test_quotes__dsl
    ### PUT README CODE BELOW ###

    # require 'wgit'
    # require 'json'

    # include Wgit::DSL

    start  'http://quotes.toscrape.com/tag/humor/'
    follow "//li[@class='next']/a/@href"

    extract :quotes,  "//div[@class='quote']/span[@class='text']", singleton: false
    extract :authors, "//div[@class='quote']/span/small",          singleton: false

    quotes = []

    crawl_site do |doc|
      doc.quotes.zip(doc.authors).each do |arr|
        quotes << {
          quote:  arr.first,
          author: arr.last
        }
      end
    end

    # puts JSON.generate(quotes)

    ### PUT README CODE ABOVE ###

    assert_equal 12, quotes.size

    # Clean up the extractors for other tests.
    Wgit::Document.remove_extractor :quotes
    Wgit::Document.remove_extractor :authors
  end

  def test_quotes__dsl_index
    ### PUT README CODE BELOW ###

    # require 'wgit'

    # include Wgit::DSL

    # Wgit.logger.level = Logger::WARN

    # connection_string 'mongodb://user:password@localhost/crawler'

    start  'http://quotes.toscrape.com/tag/humor/'
    follow "//li[@class='next']/a/@href"

    extract :quotes,  "//div[@class='quote']/span[@class='text']", singleton: false
    extract :authors, "//div[@class='quote']/span/small",          singleton: false

    index_site
    results = search 'prejudice', stream: nil

    ### PUT README CODE ABOVE ###

    assert_equal 1, results.size
    assert_equal 'http://quotes.toscrape.com/tag/humor/page/2/', results.first.url

    # Clean up the extractors for other tests.
    Wgit::Document.remove_extractor :quotes
    Wgit::Document.remove_extractor :authors
  end

  def test_quotes__classes
    ### PUT README CODE BELOW ###

    # require 'wgit'
    # require 'json'

    crawler = Wgit::Crawler.new
    url     = Wgit::Url.new('http://quotes.toscrape.com/tag/humor/')
    quotes  = []

    Wgit::Document.define_extractor(:quotes,  "//div[@class='quote']/span[@class='text']", singleton: false)
    Wgit::Document.define_extractor(:authors, "//div[@class='quote']/span/small",          singleton: false)

    crawler.crawl_site(url, follow: "//li[@class='next']/a/@href") do |doc|
      doc.quotes.zip(doc.authors).each do |arr|
        quotes << {
          quote:  arr.first,
          author: arr.last
        }
      end
    end

    # puts JSON.generate(quotes)

    ### PUT README CODE ABOVE ###

    assert_equal 12, quotes.size

    # Clean up the extractors for other tests.
    Wgit::Document.remove_extractor :quotes
    Wgit::Document.remove_extractor :authors
  end
end
