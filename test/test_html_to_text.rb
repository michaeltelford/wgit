require_relative 'helpers/test_helper'

# Test class for utility module functions.
class TestUtils < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_extract_text__anchors
    url = 'http://example.com'.to_url
    html = File.read './test/mock/fixtures/anchor_display.html'
    doc = Wgit::Document.new url, html

    assert_equal ['About', 'Foo Location Bar', 'Contact Contact2Contact3'], doc.text
  end

  def test_extract_text__spans
    url = 'http://example.com'.to_url
    html = File.read './test/mock/fixtures/span_display.html'
    doc = Wgit::Document.new url, html

    assert_equal [
      'Running the following Wgit code will programmatically configure your database:',
      "db = Wgit::Database.new '<connection_string>'"
    ], doc.text
  end

  def test_extract_text__divs
    url = 'http://example.com'.to_url
    html = File.read './test/mock/fixtures/div_display.html'
    doc = Wgit::Document.new url, html

    assert_equal %w[foo bar], doc.text
  end

  def test_extract_text__getting_started_wiki
    url = 'http://example.com'.to_url
    html = File.read './test/mock/fixtures/getting_started.html'
    doc = Wgit::Document.new url, html

    assert_equal %w[todo], doc.text
  end
end
