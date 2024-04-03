require_relative 'helpers/test_helper'

# Test class for the data Model methods.
class TestModel < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  # Runs after every test.
  def teardown
    Wgit::Model.set_default_search_fields

    Wgit::Model.include_doc_html  = false
    Wgit::Model.include_doc_score = false
  end

  def test_search_fields__default
    assert_equal Wgit::Model::DEFAULT_SEARCH_FIELDS, Wgit::Model.search_fields
  end

  def test_set_search_fields__fails
    ex = assert_raises(StandardError) { Wgit::Model.set_search_fields(true) }
    assert_equal 'fields must be an Array or Hash, not a TrueClass', ex.message
  end

  def test_set_search_fields__symbols
    fields = Wgit::Model.set_search_fields(%i[title code])

    assert_equal({ title: 1, code: 1 }, fields)
    assert_equal({ title: 1, code: 1 }, Wgit::Model.search_fields)
  end

  def test_set_search_fields__hash
    fields = Wgit::Model.set_search_fields({ title: 2, code: 1 })

    assert_equal({ title: 2, code: 1 }, fields)
    assert_equal({ title: 2, code: 1 }, Wgit::Model.search_fields)
  end

  def test_set_search_fields__db
    # Create a mock DB that is called when passed to the Wgit::Model.
    mock_db = Struct.new do
      def search_fields=(fields)
        raise unless fields == { title: 2, code: 1 }
      end
    end
    db = mock_db.new

    refute_exception do
      fields = Wgit::Model.set_search_fields({ title: 2, code: 1 }, db)
      assert_equal({ title: 2, code: 1 }, fields)
    end
  end

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

    assert Wgit::Model.include_doc_html
    assert_equal '<html>Hello</html>', model['html']
  end

  def test_document__include_score
    doc = Wgit::Document.new({
      'url' => 'http://example.com',
      'score' => 10.5
    })

    Wgit::Model.include_doc_score = true
    model = Wgit::Model.document(doc)

    assert Wgit::Model.include_doc_score
    assert_equal 10.5, model['score']
  end
end
