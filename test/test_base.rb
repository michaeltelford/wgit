require_relative 'helpers/test_helper'

# The test class is at the bottom of this file.

class QuotesCrawler < Wgit::Base
  mode   :crawl_site
  start  'http://quotes.toscrape.com/tag/humor/'
  follow "//li[@class='next']/a/@href"

  # We use the 2 suffix to avoid conflicting with tests elsewhere.
  extract :quotes2,  "//div[@class='quote']/span[@class='text']", singleton: false
  extract :authors2, "//div[@class='quote']/span/small",          singleton: false

  def parse(doc)
    doc.quotes2.zip(doc.authors2).each do |arr|
      yield({
        quote:  arr.first,
        author: arr.last
      })
    end
  end
end

class NoParseCrawler < Wgit::Base
  mode   :crawl
  start  'http://quotes.toscrape.com/tag/humor/'
  follow "//li[@class='next']/a/@href"
end

class DefaultModeCrawler < Wgit::Base
  start 'http://quotes.toscrape.com/tag/humor/'

  def parse(doc)
    yield doc.url
  end
end

class SetupTeardownCrawler < Wgit::Base
  attr_reader :count

  start 'http://quotes.toscrape.com/tag/humor/'

  def initialize
    @count = 0
  end

  def setup
    @count += 1
  end

  def parse(doc)
    @count += 1
  end

  def teardown
    @count += 1
  end
end

# Test class for the Base class logic.
class TestBase < TestHelper
  # Runs before every test.
  def setup; end

  def test_quotes_crawler
    quotes = []
    QuotesCrawler.run { |quote| quotes << quote }

    assert_equal 12, quotes.size
    assert({
      quote: "“A lady's imagination is very rapid; it jumps from admiration to love, from love to matrimony in a moment.”",
      author: 'Jane Austen'
    }, quotes.last)

    # Clean up the extractors for other tests.
    Wgit::Document.remove_extractor :quotes2
    Wgit::Document.remove_extractor :authors2
  end

  def test_no_parse_crawler
    ex = assert_raises(StandardError) { NoParseCrawler.run }
    assert_equal 'NoParseCrawler must respond_to? #parse(doc, &block)', ex.message
  end

  def test_default_mode_crawler
    DefaultModeCrawler.run do |url|
      assert_equal 'http://quotes.toscrape.com/tag/humor/', url
    end
  end

  def test_setup_teardown_crawler
    crawler = SetupTeardownCrawler.run
    assert_equal 3, crawler.count
  end
end
