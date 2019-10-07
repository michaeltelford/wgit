require_relative 'helpers/test_helper'

# Test class for the data Model methods.
class TestModel < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_url
    url = Wgit::Url.new(
      'http://example.com',
      crawled: true,
      date_crawled: Time.now,
      crawl_duration: 1.3
    )

    model = Wgit::Model.url(url)

    assert_equal %w[crawl_duration crawled date_crawled url], model.keys.sort
    refute model.values.any?(&:nil?)
  end

  def test_document
    doc = Wgit::Document.new Wgit::Url.new(
      'http://example.com',
      crawled: true,
      date_crawled: Time.now,
      crawl_duration: 1.3
    )

    model = Wgit::Model.document(doc)

    assert_equal %w[author base keywords links text title url], model.keys.sort
    assert_equal %w[crawl_duration crawled date_crawled url], model['url'].keys.sort
    refute model['url'].values.any?(&:nil?)
  end
end
