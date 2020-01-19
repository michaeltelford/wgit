require_relative 'helpers/test_helper'

# Tests the ability to extend the Wgit::Document functionality by extracting
# custom page elements that aren't extracted by default.
#
# WARNING: Certain tests will clear down the DB prior to the test run.
# NOTE: Every test case should clean up after itself by removing any defined
# extensions in the 'teardown' method to avoid affecting other tests.
class TestDocumentExtension < TestHelper
  include Wgit::DatabaseHelper

  # Runs before every test.
  def setup; end

  # Runs after every test and should remove all defined extensions
  # to avoid affecting other tests.
  def teardown
    if Wgit::Document.remove_extension(:table_text)
      Wgit::Document.send(:remove_method, :table_text)
    end

    if Wgit::Document.remove_extension(:tables)
      Wgit::Document.send(:remove_method, :tables)
    end

    if Wgit::Document.remove_extension(:code_snippets)
      Wgit::Document.send(:remove_method, :code_snippets)
    end

    if Wgit::Document.remove_extension(:code_snippet)
      Wgit::Document.send(:remove_method, :code_snippet)
    end

    if Wgit::Document.remove_extension(:img_alt)
      Wgit::Document.send(:remove_method, :img_alt)
    end

    if Wgit::Document.remove_extension(:img)
      Wgit::Document.send(:remove_method, :img)
    end

    if Wgit::Document.remove_extension(:has_div)
      Wgit::Document.send(:remove_method, :has_div)
    end

    if Wgit::Document.remove_extension(:blockquote)
      Wgit::Document.send(:remove_method, :blockquote)
    end

    if Wgit::Document.remove_extension(:code)
      Wgit::Document.send(:remove_method, :code)
    end

    if Wgit::Document.remove_extension(:single)
      Wgit::Document.send(:remove_method, :single)
    end

    if Wgit::Document.remove_extension(:array)
      Wgit::Document.send(:remove_method, :array)
    end
  end

  def test_text_elements_extension
    Wgit::Document.text_elements << :table

    doc = Wgit::Document.new(
      'http://some_url.com',
      <<~HTML
      <html>
        <p>Hello world!</p>
        <table>My table</table>
      </html>
      HTML
    )

    assert_equal ['Hello world!', 'My table'], doc.text
    assert Wgit::Document.text_elements.include?(:table)

    Wgit::Document.text_elements.delete(:table)
  end

  def test_document_extension__with_defaults
    # Test default scenario - singleton: true and text_content_only: true.
    name = Wgit::Document.define_extension(:table_text, '//table',
                                           singleton: true, text_content_only: true)

    doc = Wgit::Document.new(
      'http://some_url.com'.to_url,
      "<html><p>Hello world!</p><table><th>Header Text</th>\
<th>Another Header</th></table></html>"
    )

    assert_equal :table_text, name
    assert doc.respond_to? :table_text
    table_text = doc.table_text

    assert_instance_of String, table_text
    assert_equal 'Header TextAnother Header', table_text
  end

  def test_document_extension__with_non_defaults
    # Test singleton: false and text_content_only: false
    # NOTE: test_readme_code_examples defines :tables so we use :tables.
    name = Wgit::Document.define_extension(:tables, '//table',
                                           singleton: false, text_content_only: false)

    doc = Wgit::Document.new(
      'http://some_url.com'.to_url,
      <<~HTML
        <html>
          <p>Hello world!</p>
          <table><th>Header Text</th><th>Another Header</th></table>
          <table><th>Header Text 2</th><th>Another Header 2</th></table>
        </html>
      HTML
    )

    assert_equal :tables, name
    assert doc.respond_to? :tables
    tables = doc.tables

    assert_instance_of Nokogiri::XML::NodeSet, tables
    assert_equal 2, tables.length
    assert_equal 2, doc.stats[:tables]

    assert_instance_of Nokogiri::XML::Element, tables.first
  end

  def test_document_extension__with_mixed_defaults
    # Test singleton: false and text_content_only: true
    name = Wgit::Document.define_extension(
      :code_snippets,
      '//code',
      singleton: false,
      text_content_only: true
    )

    doc = Wgit::Document.new(
      'http://some_url.com'.to_url,
      '<html><code>curl</code><code>wget</code><code>wgit</code></html>'
    )

    assert_equal :code_snippets, name
    assert doc.respond_to? :code_snippets
    snippets = doc.code_snippets

    assert_instance_of Array, snippets
    assert_equal 3, snippets.length
    assert snippets.all? { |snippet| snippet.instance_of? String }
    assert_equal %w[curl wget wgit], snippets
  end

  def test_document_extension__with_mixed_defaults_2
    # Test singleton: true and text_content_only: false
    name = Wgit::Document.define_extension(
      :code_snippet,
      '//code',
      singleton: true,
      text_content_only: false
    )

    doc = Wgit::Document.new(
      'http://some_url.com'.to_url,
      '<html><code>curl</code><code>wget</code><code>wgit</code></html>'
    )

    assert_equal :code_snippet, name
    assert doc.respond_to? :code_snippet
    snippet = doc.code_snippet

    assert_instance_of Nokogiri::XML::Element, snippet
    assert_equal 'curl', snippet.content
  end

  def test_document_extension__change_simple_value
    # We get the first image's alt text value and then upcase it.
    # default_opts = { singleton: true, text_content_only: true }
    name = Wgit::Document.define_extension(:img_alt, '//img/@alt') do |value|
      value&.upcase
    end

    doc = Wgit::Document.new(
      'http://some_url.com'.to_url,
      '<html><p>Hello world!</p>\
<img src="smiley.gif" alt="Smiley face" height="10" width="12"></html>'
    )

    assert_equal :img_alt, name
    assert doc.respond_to? :img_alt
    alt_text = doc.img_alt

    assert_instance_of String, alt_text
    assert_equal 'SMILEY FACE', alt_text
  end

  def test_document_extension__examine_value
    # We get the first image's dimensions to determine the area value but by
    # returning nil we don't change the actual Nokogiri object.
    obj = nil
    area = 0.0

    opts = { singleton: true, text_content_only: false }
    name = Wgit::Document.define_extension(:img, '//img', opts) do |img_obj|
      obj = img_obj # For assertions further down.
      height = img_obj.get_attribute(:height).to_i
      width = img_obj.get_attribute(:width).to_i
      area = height * width
      nil
    end

    doc = Wgit::Document.new(
      'http://some_url.com'.to_url,
      '<html><p>Hello world!</p>\
<img src="smiley.gif" alt="Smiley face" height="10" width="12"></html>'
    )

    assert_equal :img, name
    assert doc.respond_to? :img
    img = doc.img

    assert_instance_of Nokogiri::XML::Element, img
    assert_equal obj, img
    assert_equal 120, area
  end

  def test_document_extension__return_predicate_from_html
    # Define an extension which returns an elements presence (predicate).
    Wgit::Document.define_extension(:has_div, '//div') do |value|
      value ? true : false
    end
    url = 'http://example.com'.to_url

    doc = Wgit::Document.new url, '<html></html>'
    refute doc.has_div

    doc = Wgit::Document.new url, '<html><div></div></html>'
    assert doc.has_div
  end

  def test_document_extension__return_predicate_from_object
    # Define an extension which returns an elements presence (predicate).
    Wgit::Document.define_extension(:has_div, '//div') do |value|
      value ? true : false
    end

    doc = Wgit::Document.new('url' => 'http://example.com', 'has_div' => false)
    refute doc.has_div

    doc = Wgit::Document.new('url' => 'http://example.com', 'has_div' => true)
    assert doc.has_div
  end

  def test_define_extension__init_from_crawl
    # We get the first blockquote on the crawled page.
    # default_opts = { singleton: true, text_content_only: true }
    name = Wgit::Document.define_extension(:blockquote, '//blockquote')

    url = 'https://motherfuckingwebsite.com/'.to_url
    doc = Wgit::Crawler.new.crawl_url(url)

    assert_equal :blockquote, name
    assert doc.respond_to? :blockquote
    blockquote = doc.blockquote

    assert_instance_of String, blockquote
    assert_equal "\"Good design is as little design as possible.\"\n            - some German motherfucker", blockquote
  end

  def test_document_extension__init_from_database
    clear_db

    # Define a text extension.
    Wgit::Document.text_elements << :table

    # Define a Document extension.
    name = Wgit::Document.define_extension(
      :table_text, '//table',
      singleton: true, text_content_only: true
    )

    time = '2019-10-08T07:12:15.601+00:00'
    url = Wgit::Url.new(
      'http://some_url.com',
      crawled: true,
      date_crawled: time,
      crawl_duration: 0.8
    )
    doc = Wgit::Document.new(
      url,
      "<html><p>Hello world!</p>\
<a href='https://made-up-link.com'>Click this link.</a>\
<table>Boomsk<th>Header Text</th><th>Another Header</th></table></html>"
    )

    # Some basic Document assertions before the database interactions.
    assert_equal :table_text, name
    assert ['https://made-up-link.com'], doc.links
    assert doc.respond_to? :table_text
    assert_equal 'BoomskHeader TextAnother Header', doc.table_text

    db = Wgit::Database.new
    db.insert doc # Uses Document#to_h and Model.document.

    assert doc?(
      url: {
        url: 'http://some_url.com',
        crawled: true,
        date_crawled: time,
        crawl_duration: 0.8
      },
      base: nil,
      title: nil,
      author: nil,
      keywords: nil,
      links: ['https://made-up-link.com'],
      text: ['Hello world!', 'Click this link.', 'Boomsk', 'Header Text', 'Another Header'],
      table_text: 'BoomskHeader TextAnother Header'
    )

    results = db.search 'Hello world'
    assert_equal 1, results.length

    db_doc = results.first
    refute_equal doc.object_id, db_doc.object_id

    assert_instance_of Wgit::Document, db_doc
    assert_equal 'http://some_url.com', db_doc.url
    assert_equal ['https://made-up-link.com'], db_doc.links
    assert_equal ['Hello world!', 'Click this link.', 'Boomsk', 'Header Text', 'Another Header'], db_doc.text
    assert db_doc.respond_to? :table_text
    assert_instance_of String, db_doc.table_text
    assert_equal 'BoomskHeader TextAnother Header', db_doc.table_text
    assert Wgit::Document.text_elements.include?(:table)

    Wgit::Document.text_elements.delete(:table)
  end

  def test_document_extension__init_from_mongo_doc
    # Simulate a Wgit::Document with extensions initialized and stored in
    # MongoDB before being retrieved as a Hash instance.
    extended_mongo_doc = {
      'url' => 'https://google.co.uk',
      'score' => 2.1,
      'title' => 'Test Page 233',
      'code' => "puts 'hello world'"
    }

    # Define the 'code' Document extension.
    name = Wgit::Document.define_extension(:code, '//code',
                                           singleton: true, text_content_only: true)

    doc = Wgit::Document.new extended_mongo_doc

    assert_equal :code, name
    assert doc.respond_to? :code
    assert_equal extended_mongo_doc['url'], doc.url
    assert_equal extended_mongo_doc['score'], doc.score
    assert_equal extended_mongo_doc['title'], doc.title
    assert_equal extended_mongo_doc['code'], doc.code
  end

  def test_define_extension__invalid_var_name
    e = assert_raises(StandardError) do
      Wgit::Document.define_extension(:ABC, '//blah')
    end

    assert_equal "var must match #{Wgit::Document::REGEX_EXTENSION_NAME}", e.message
  end

  def test_document_empty_singleton_value__from_html
    name = Wgit::Document.define_extension(:single, '//single',
                                           singleton: true, text_content_only: true)

    doc = Wgit::Document.new(
      'http://some_url.com'.to_url,
      "<html><p>Hello world!</p><table><th>Header Text</th>\
<th>Another Header</th></table></html>"
    )

    assert_equal :single, name
    assert doc.respond_to? :single
    assert_nil doc.single
  end

  def test_document_empty_array_value__from_html
    name = Wgit::Document.define_extension(:array, '//array',
                                           singleton: false, text_content_only: true)

    doc = Wgit::Document.new(
      'http://some_url.com'.to_url,
      "<html><p>Hello world!</p><table><th>Header Text</th>\
<th>Another Header</th></table></html>"
    )

    assert_equal :array, name
    assert doc.respond_to? :array
    assert_equal [], doc.array
  end

  def test_document_empty_singleton_value__from_obj
    name = Wgit::Document.define_extension(:single, '//single',
                                           singleton: true, text_content_only: true)

    doc = Wgit::Document.new(
      'url' => 'https://google.co.uk'
    )

    assert_equal :single, name
    assert doc.respond_to? :single
    assert_nil doc.single
  end

  def test_document_empty_array_value__from_obj
    name = Wgit::Document.define_extension(:array, '//array',
                                           singleton: false, text_content_only: true)

    doc = Wgit::Document.new(
      'url' => 'https://google.co.uk'
    )

    assert_equal :array, name
    assert doc.respond_to? :array
    assert_equal [], doc.array
  end

  def test_block_values__from_html
    Wgit::Document.define_extension(:code, '//code') do |value, source, type|
      refute_nil value
      assert_instance_of Wgit::Document, source
      assert_equal :document, type
    end

    Wgit::Document.new(
      'http://some_url.com'.to_url,
      "<html><code>puts 'hello world'</code</html>"
    )
  end

  def test_block_values__from_object
    extended_mongo_doc = {
      'url' => 'https://google.co.uk',
      'score' => 2.1,
      'title' => 'Test Page 233',
      'code' => "puts 'hello world'"
    }

    Wgit::Document.define_extension(:code, '//code') do |value, source, type|
      refute_nil value
      assert_instance_of Hash, source
      assert_equal :object, type
    end

    Wgit::Document.new extended_mongo_doc
  end

  def test_remove_extension__success
    assert %i[base title author keywords links text], Wgit::Document.extensions
    Wgit::Document.define_extension(:blah, '//blah')
    assert Wgit::Document.extensions.include?(:blah)

    assert Wgit::Document.remove_extension(:blah)
    refute Wgit::Document.extensions.include?(:blah)
  end

  def test_remove_extension__failure
    # blah2 doesn't exist so false should be returned.
    refute Wgit::Document.remove_extension(:blah2)
  end
end
