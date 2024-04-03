require_relative 'helpers/test_helper'

# Tests the ability to extend the Wgit::Document functionality by extracting
# custom page elements that aren't extracted by default.
#
# WARNING: Certain tests will clear down the DB prior to the test run.
# NOTE: Every test case should clean up after itself by removing any defined
# extractors in the 'teardown' method to avoid affecting other tests.
class TestDocumentExtractors < TestHelper
  include MongoDBHelper

  # Runs before every test.
  def setup
    @html = <<~HTML
    <html>
      <p>Paragraph 1</p>
      <p>Paragraph 2</p>
      <p>Paragraph 3</p>
    </html>
    HTML
  end

  # Runs after every test and should remove all defined extractors
  # to avoid affecting other tests.
  def teardown
    if Wgit::Document.text_elements.include?(:table)
      Wgit::Document.text_elements.delete(:table)
    end

    unless Wgit::Document.text_elements.include?(:p)
      Wgit::Document.text_elements << :p
    end

    if Wgit::Document.to_h_ignore_vars.include?('@data')
      Wgit::Document.to_h_ignore_vars.delete('@data')
    end

    unless Wgit::Document.to_h_ignore_vars.include?('@parser')
      Wgit::Document.to_h_ignore_vars << '@parser'
    end

    if Wgit::Document.remove_extractor(:table_text)
      Wgit::Document.send(:remove_method, :table_text)
    end

    if Wgit::Document.remove_extractor(:tables)
      Wgit::Document.send(:remove_method, :tables)
    end

    if Wgit::Document.remove_extractor(:code_snippets)
      Wgit::Document.send(:remove_method, :code_snippets)
    end

    if Wgit::Document.remove_extractor(:code_snippet)
      Wgit::Document.send(:remove_method, :code_snippet)
    end

    if Wgit::Document.remove_extractor(:img_alt)
      Wgit::Document.send(:remove_method, :img_alt)
    end

    if Wgit::Document.remove_extractor(:img)
      Wgit::Document.send(:remove_method, :img)
    end

    if Wgit::Document.remove_extractor(:has_div)
      Wgit::Document.send(:remove_method, :has_div)
    end

    if Wgit::Document.remove_extractor(:blockquote)
      Wgit::Document.send(:remove_method, :blockquote)
    end

    if Wgit::Document.remove_extractor(:code)
      Wgit::Document.send(:remove_method, :code)
    end

    if Wgit::Document.remove_extractor(:single)
      Wgit::Document.send(:remove_method, :single)
    end

    if Wgit::Document.remove_extractor(:array)
      Wgit::Document.send(:remove_method, :array)
    end
  end

  def test_text_elements__addition
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
  end

  def test_text_elements__deletion
    Wgit::Document.text_elements.delete(:p)

    doc = Wgit::Document.new(
      'http://some_url.com',
      <<~HTML
      <html>
        <p>Hello world!</p>
        <code>obj.method()</code>
      </html>
      HTML
    )

    assert_equal ['obj.method()'], doc.text
    refute Wgit::Document.text_elements.include?(:p)
  end

  def test_to_h_ignore_vars__addition
    Wgit::Document.to_h_ignore_vars << '@data'

    doc = Wgit::Document.new(
      'http://some_url.com',
      <<~HTML
      <html>
        <p>Hello world!</p>
      </html>
      HTML
    )
    doc.instance_variable_set(:@data, "my data")

    assert_equal "my data", doc.instance_variable_get(:@data)
    refute doc.to_h.keys.include?('data')
  end

  def test_to_h_ignore_vars__deletion
    Wgit::Document.to_h_ignore_vars.delete('@parser')

    doc = Wgit::Document.new(
      'http://some_url.com',
      <<~HTML
      <html>
        <p>Hello world!</p>
      </html>
      HTML
    )

    refute Wgit::Document.to_h_ignore_vars.include?('@parser')
    refute_nil doc.parser
    assert doc.to_h.keys.include?('parser')
  end

  ### DEFINE EXTRACTOR TESTS ###

  def test_document_extractor__with_defaults
    # Test default scenario - singleton: true and text_content_only: true.
    name = Wgit::Document.define_extractor(:table_text, '//table',
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

    assert doc.respond_to? :table_text=
    doc.table_text = 'Hello World'
    assert_equal 'Hello World', doc.table_text
  end

  def test_document_extractor__with_non_defaults
    # Test singleton: false and text_content_only: false
    name = Wgit::Document.define_extractor(:tables, '//table',
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

  def test_document_extractor__with_mixed_defaults
    # Test singleton: false and text_content_only: true
    name = Wgit::Document.define_extractor(
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

  def test_document_extractor__with_mixed_defaults_2
    # Test singleton: true and text_content_only: false
    name = Wgit::Document.define_extractor(
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

  def test_document_extractor__change_simple_value__from_html
    # We get the first image's alt text value and then upcase it.
    # default_opts = { singleton: true, text_content_only: true }
    name = Wgit::Document.define_extractor(:img_alt, '//img/@alt') do |value|
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

  def test_document_extractor__change_simple_value__from_object
    # We get the first image's alt text value and then upcase it.
    # default_opts = { singleton: true, text_content_only: true }
    name = Wgit::Document.define_extractor(:img_alt, '//img/@alt') do |value|
      value&.upcase
    end

    doc = Wgit::Document.new({
      'url' => 'http://example.com', 'img_alt' => 'Smiley face'
    })

    assert_equal :img_alt, name
    assert doc.respond_to? :img_alt
    alt_text = doc.img_alt

    assert_instance_of String, alt_text
    assert_equal 'SMILEY FACE', alt_text
  end

  def test_document_extractor__examine_value__from_html
    # We get the first image's dimensions to determine the area value but we
    # don't change the actual Nokogiri object.
    obj = nil
    area = 0.0

    opts = { singleton: true, text_content_only: false }
    name = Wgit::Document.define_extractor(:img, '//img', opts) do |img_obj|
      obj = img_obj # Used for assertions further down.

      height = img_obj.get_attribute(:height).to_i
      width = img_obj.get_attribute(:width).to_i
      area = height * width

      img_obj # Return the object unchanged.
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

  def test_document_extractor__examine_value__from_object
    # We get the first image's dimensions to determine the area value but we
    # don't change the actual value.
    obj = nil
    area = 0.0

    opts = { singleton: true, text_content_only: false }
    name = Wgit::Document.define_extractor(:img, '//img', opts) do |img_obj|
      obj = img_obj # Used for assertions further down.

      height = img_obj.fetch('height').to_i
      width = img_obj.fetch('width').to_i
      area = height * width

      img_obj # Return the object unchanged.
    end

    hash_obj = {
      'url' => 'http://example.com', 'img' => { 'height' => 10, 'width' => 12 }
    }
    doc = Wgit::Document.new(hash_obj)

    assert_equal :img, name
    assert doc.respond_to? :img
    img = doc.img

    assert_equal hash_obj['img'], img
    assert_equal obj, img
    assert_equal 120, area
  end

  def test_document_extractor__return_predicate_from_html
    # Define an extractor which returns an elements presence (predicate).
    Wgit::Document.define_extractor(:has_div, '//div') do |value|
      value ? true : false
    end
    url = 'http://example.com'.to_url

    doc = Wgit::Document.new url, '<html></html>'
    refute doc.has_div

    doc = Wgit::Document.new url, '<html><div></div></html>'
    assert doc.has_div
  end

  def test_document_extractor__return_predicate_from_object
    # Define an extractor which returns an elements presence (predicate).
    Wgit::Document.define_extractor(:has_div, '//div') do |value|
      value ? true : false
    end

    doc = Wgit::Document.new({'url' => 'http://example.com', 'has_div' => false})
    refute doc.has_div

    doc = Wgit::Document.new({'url' => 'http://example.com', 'has_div' => true})
    assert doc.has_div
  end

  def test_define_extractor__init_from_crawl
    # We get the first blockquote on the crawled page.
    # default_opts = { singleton: true, text_content_only: true }
    name = Wgit::Document.define_extractor(:blockquote, '//blockquote')

    url = 'https://motherfuckingwebsite.com/'.to_url
    doc = Wgit::Crawler.new.crawl_url(url)

    assert_equal :blockquote, name
    assert doc.respond_to? :blockquote
    blockquote = doc.blockquote

    assert_instance_of String, blockquote
    assert_equal "\"Good design is as little design as possible.\"\n            - some German motherfucker", blockquote
  end

  def test_document_extractor__init_from_database
    empty_db

    # Define a text extractor.
    Wgit::Document.text_elements << :table

    # Define a Document extractor.
    name = Wgit::Document.define_extractor(
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

    db.insert doc # Uses Document#to_h and Wgit::Model.document.

    assert doc?(
      url: {
        url: 'http://some_url.com',
        crawled: true,
        date_crawled: time,
        crawl_duration: 0.8,
        redirects: {}
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

  def test_document_extractor__init_from_mongo_doc
    # Simulate a Wgit::Document with extractors initialized and stored in
    # MongoDB before being retrieved as a Hash instance.
    extended_mongo_doc = {
      'url' => 'https://google.co.uk',
      'score' => 2.1,
      'title' => 'Test Page 233',
      'code' => "puts 'hello world'"
    }

    # Define the 'code' Document extractor.
    name = Wgit::Document.define_extractor(:code, '//code',
                                           singleton: true, text_content_only: true)

    doc = Wgit::Document.new extended_mongo_doc

    assert_equal :code, name
    assert doc.respond_to? :code
    assert_equal extended_mongo_doc['url'], doc.url
    assert_equal extended_mongo_doc['score'], doc.score
    assert_equal extended_mongo_doc['title'], doc.title
    assert_equal extended_mongo_doc['code'], doc.code
  end

  def test_define_extractor__invalid_var_name
    e = assert_raises(StandardError) do
      Wgit::Document.define_extractor(:ABC, '//blah')
    end

    assert_equal "var must match #{Wgit::Document::REGEX_EXTRACTOR_NAME}", e.message
  end

  def test_document_empty_singleton_value__from_html
    name = Wgit::Document.define_extractor(:single, '//single',
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
    name = Wgit::Document.define_extractor(:array, '//array',
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
    name = Wgit::Document.define_extractor(:single, '//single',
                                           singleton: true, text_content_only: true)

    doc = Wgit::Document.new({
      'url' => 'https://google.co.uk'
    })

    assert_equal :single, name
    assert doc.respond_to? :single
    assert_nil doc.single
  end

  def test_document_empty_array_value__from_obj
    name = Wgit::Document.define_extractor(:array, '//array',
                                           singleton: false, text_content_only: true)

    doc = Wgit::Document.new({
      'url' => 'https://google.co.uk'
    })

    assert_equal :array, name
    assert doc.respond_to? :array
    assert_equal [], doc.array
  end

  def test_block_values__from_html
    Wgit::Document.define_extractor(:code, '//code') do |value, source, type|
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

    Wgit::Document.define_extractor(:code, '//code') do |value, source, type|
      refute_nil value
      assert_instance_of Hash, source
      assert_equal :object, type
    end

    Wgit::Document.new extended_mongo_doc
  end

  ### REMOVE EXTRACTOR TESTS ###

  def test_remove_extractor__success
    assert %i[base title author keywords links text], Wgit::Document.extractors
    Wgit::Document.define_extractor(:blah, '//blah')
    assert Wgit::Document.extractors.include?(:blah)

    assert Wgit::Document.remove_extractor(:blah)
    refute Wgit::Document.extractors.include?(:blah)
  end

  def test_remove_extractor__failure
    # blah2 doesn't exist so false should be returned.
    refute Wgit::Document.remove_extractor(:blah2)
  end

  def test_remove_extractors
    refute Wgit::Document.extractors.empty?

    Wgit::Document.remove_extractors
    assert Wgit::Document.extractors.empty?

    # Assert func is idempotent.
    Wgit::Document.remove_extractors
    assert Wgit::Document.extractors.empty?
  ensure
    load './lib/wgit/document_extractors.rb'
  end

  ### EXTRACT TESTS ###

  def test_extract__xpath_el__true_and_true
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    result = doc.extract '//p', singleton: true, text_content_only: true

    assert_instance_of String, result
    assert_equal "Paragraph 1", result
  end

  def test_extract__xpath_el__false_and_false
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    result = doc.extract '//p', singleton: false, text_content_only: false

    assert_instance_of Nokogiri::XML::NodeSet, result
    assert result.all? { |el| el.instance_of?(Nokogiri::XML::Element) }
    assert_equal 3, result.size
    assert_equal ["Paragraph 1", "Paragraph 2", "Paragraph 3"], result.map(&:content)
  end

  def test_extract__xpath_el__true_and_false
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    result = doc.extract '//p', singleton: true, text_content_only: false

    assert_instance_of Nokogiri::XML::Element, result
    assert_equal "Paragraph 1", result.content
  end

  def test_extract__xpath_el__false_and_true
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    result = doc.extract '//p', singleton: false, text_content_only: true

    assert_instance_of Array, result
    assert result.all? { |el| el.instance_of?(String) }
    assert_equal ["Paragraph 1", "Paragraph 2", "Paragraph 3"], result
  end

  def test_extract__xpath_text__true_and_true
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    result = doc.extract '//p/text()', singleton: true, text_content_only: true

    assert_instance_of String, result
    assert_equal "Paragraph 1", result
  end

  def test_extract__xpath_text__false_and_false
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    result = doc.extract '//p/text()', singleton: false, text_content_only: false

    assert_instance_of Nokogiri::XML::NodeSet, result
    assert result.all? { |el| el.instance_of?(Nokogiri::XML::Text) }
    assert_equal 3, result.size
    assert_equal ["Paragraph 1", "Paragraph 2", "Paragraph 3"], result.map(&:content)
  end

  def test_extract__xpath_text__true_and_false
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    result = doc.extract '//p/text()', singleton: true, text_content_only: false

    assert_instance_of Nokogiri::XML::Text, result
    assert_equal "Paragraph 1", result.content
  end

  def test_extract__xpath_text__false_and_true
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    result = doc.extract '//p/text()', singleton: false, text_content_only: true

    assert_instance_of Array, result
    assert result.all? { |el| el.instance_of?(String) }
    assert_equal ["Paragraph 1", "Paragraph 2", "Paragraph 3"], result
  end

  def test_extract__block
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    result = doc.extract '//p/text()' do |value, source, type|
      assert_instance_of String, value
      assert_instance_of Wgit::Document, source
      assert_equal doc, source
      assert_equal :document, type

      nil # Is returned as the result.
    end

    assert_nil result
    assert_instance_of String, doc.extract('//p/text()') { |value| value }
  end
end
