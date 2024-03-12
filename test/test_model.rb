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

    assert_equal %w[crawl_duration crawled date_crawled redirects url], model.keys.sort
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

    assert_equal %w[author base description keywords links text title url], model.keys.sort
    assert_equal %w[crawl_duration crawled date_crawled redirects url], model['url'].keys.sort
    refute model['url'].values.any?(&:nil?)
  end

  def test_document__include_html
    doc = Wgit::Document.new 'http://example.com'.to_url, '<html>Hello</html>'

    Wgit::Model.include_doc_html = true
    model = Wgit::Model.document(doc)

    assert_equal '<html>Hello</html>', model['html']
  end

  def test_document__include_score
    doc = Wgit::Document.new({
      'url' => 'http://example.com',
      'score' => 10.5
    })

    Wgit::Model.include_doc_score = true
    model = Wgit::Model.document(doc)

    assert_equal 10.5, model['score']
  end

  # Runs after every test.
  def teardown
    Wgit::Model.include_doc_html  = false
    Wgit::Model.include_doc_score = false
  end
end
