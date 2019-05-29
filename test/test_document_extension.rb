require_relative "helpers/test_helper"

# Tests the ability to extend the Wgit::Document functionality by extracting
# custom page elements that aren't extracted by default.
# WARNING: Certain tests will clear down the DB prior to the test run.
# NOTE: Every test case should clean up after itself by removing any defined 
# extensions in the 'teardown' method to avoid affecting other tests.
class TestDocumentExtension < TestHelper
  include Wgit::DatabaseHelper
  
  # Runs before every test.
  def setup
  end

  # Runs after every test and should remove all defined extensions
  # to avoid affecting other tests.
  def teardown
    if Wgit::Document.remove_extension(:table_text)
      Wgit::Document.send(:remove_method, :table_text)
    end

    if Wgit::Document.remove_extension(:tables2)
      Wgit::Document.send(:remove_method, :tables2)
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

    if Wgit::Document.remove_extension(:blockquote)
      Wgit::Document.send(:remove_method, :blockquote)
    end

    if Wgit::Document.remove_extension(:table_text2)
      Wgit::Document.send(:remove_method, :table_text2)
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

    if Wgit::Document.remove_extension(:single2)
      Wgit::Document.send(:remove_method, :single2)
    end

    if Wgit::Document.remove_extension(:array2)
      Wgit::Document.send(:remove_method, :array2)
    end
  end
  
  # Extends the text elements by processing <a> tags and adds the tag text 
  # into Document#text. 
  def test_text_elements_extension
    Wgit::Document.text_elements << :a
    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p>\
<a href='https://made-up-link.com'>Click this link.</a></html>"
    )

    assert ["https://made-up-link.com"], doc.links
    assert ["Hello world!", "Click this link."], doc.text

    assert_equal :a, Wgit::Document.text_elements.delete(:a)
  end
  
  def test_virtual_attributes_extension_with_defaults
    # Test default scenario - singleton: true and text_content_only: true.
    name = Wgit::Document.define_extension(:table_text, "//table", 
                                    singleton: true, text_content_only: true)
    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p><table><th>Header Text</th>\
<th>Another Header</th></table></html>"
    )
    
    assert_equal :init_table_text, name
    assert doc.respond_to? :table_text
    table_text = doc.table_text
    
    assert_instance_of String, table_text
    assert_equal "Header TextAnother Header", table_text
  end
  
  def test_virtual_attributes_extension_with_non_defaults
    # Test singleton: false and text_content_only: false
    # NOTE: test_readme_code_examples defines :tables so we use :tables2.
    name = Wgit::Document.define_extension(:tables2, "//table", 
                                    singleton: false, text_content_only: false)
    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p>\
<table><th>Header Text</th><th>Another Header</th></table></html>"
    )
    
    assert_equal :init_tables2, name
    assert doc.respond_to? :tables2
    tables = doc.tables2
    
    assert_instance_of Nokogiri::XML::NodeSet, tables
    assert_equal 1, tables.length
    
    assert_instance_of Nokogiri::XML::Element, tables.first
  end

  def test_virtual_attributes_extension_with_mixed_defaults
    # Test singleton: false and text_content_only: true
    name = Wgit::Document.define_extension(
      :code_snippets,
      "//code",
      singleton: false,
      text_content_only: true
    )

    doc = Wgit::Document.new(
      "http://some_url.com".to_url,
      "<html><code>curl</code><code>wget</code><code>wgit</code></html>"
    )

    assert_equal :init_code_snippets, name
    assert doc.respond_to? :code_snippets
    snippets = doc.code_snippets

    assert_instance_of Array, snippets
    assert_equal 3, snippets.length
    assert snippets.all? { |snippet| snippet.instance_of? String }
    assert_equal ['curl', 'wget', 'wgit'], snippets
  end

  def test_virtual_attributes_extension_with_mixed_defaults_2
    # Test singleton: true and text_content_only: false
    name = Wgit::Document.define_extension(
      :code_snippet,
      "//code",
      singleton: true,
      text_content_only: false
    )

    doc = Wgit::Document.new(
      "http://some_url.com".to_url,
      "<html><code>curl</code><code>wget</code><code>wgit</code></html>"
    )

    assert_equal :init_code_snippet, name
    assert doc.respond_to? :code_snippet
    snippet = doc.code_snippet

    assert_instance_of Nokogiri::XML::Element, snippet
    assert_equal 'curl', snippet.content
  end

  def test_virtual_attributes_extension_change_simple_value
    # We get the first image's alt text value and then upcase it.
    # default_opts = { singleton: true, text_content_only: true }
    name = Wgit::Document.define_extension(:img_alt, "//img/@alt") do |value|
      value.upcase if value
    end
    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      '<html><p>Hello world!</p>\
<img src="smiley.gif" alt="Smiley face" height="10" width="12"></html>'
    )
    
    assert_equal :init_img_alt, name
    assert doc.respond_to? :img_alt
    alt_text = doc.img_alt
    
    assert_instance_of String, alt_text
    assert_equal "SMILEY FACE", alt_text
  end

  def test_virtual_attributes_extension_examine_value
    # We get the first image's dimensions to determine the area value but by
    # returning nil we don't change the actual Nokogiri object.
    obj = nil
    area = 0.0
    
    opts = { singleton: true, text_content_only: false }
    name = Wgit::Document.define_extension(:img, "//img", opts) do |img_obj|
      obj = img_obj
      height = img_obj.get_attribute(:height).to_i
      width = img_obj.get_attribute(:width).to_i
      area = height * width
      nil
    end
    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      '<html><p>Hello world!</p>\
<img src="smiley.gif" alt="Smiley face" height="10" width="12"></html>'
    )
    
    assert_equal :init_img, name
    assert doc.respond_to? :img
    img = doc.img
    
    assert_instance_of Nokogiri::XML::Element, img
    assert_equal obj, img
    assert_equal 120, area
  end

  def test_define_extension_when_crawled
    # We get the first blockquote on the crawled page.
    # default_opts = { singleton: true, text_content_only: true }
    name = Wgit::Document.define_extension(:blockquote, "//blockquote")
    
    doc = Wgit::Crawler.new("https://motherfuckingwebsite.com/").crawl_url
    
    assert_equal :init_blockquote, name
    assert doc.respond_to? :blockquote
    blockquote = doc.blockquote
    
    assert_instance_of String, blockquote
    assert_equal "\"Good design is as little design as possible.\"\n            - some German motherfucker", blockquote
  end
  
  def test_virtual_attributes_extension_init_from_database
    clear_db
    
    # Define a text and virtual attribute extension. 
    Wgit::Document.text_elements << :a
    name = Wgit::Document.define_extension(
      :table_text2, "//table", 
      singleton: true, text_content_only: true,
    )
                                    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p>\
<a href='https://made-up-link.com'>Click this link.</a>\
<table><th>Header Text</th><th>Another Header</th></table></html>"
    )
    
    # Some basic Document assertions before the database interactions.
    assert_equal :init_table_text2, name
    assert ["https://made-up-link.com"], doc.links
    assert doc.respond_to? :table_text2
    assert_equal "Header TextAnother Header", doc.table_text2
    
    db = Wgit::Database.new
    db.insert doc # Uses Document#to_h and Model.document.
    
    assert doc?({
      url: "http://some_url.com",
      score: 0.0,
      title: nil,
      author: nil,
      keywords: nil,
      links: ["https://made-up-link.com"],
      text: ["Hello world!", "Click this link."],
      table_text2: "Header TextAnother Header"
    })
    
    results = db.search "Hello world"
    assert_equal 1, results.length
    
    db_doc = results.first
    refute_equal doc.object_id, db_doc.object_id
    
    assert_instance_of Wgit::Document, db_doc
    assert_equal "http://some_url.com", db_doc.url
    assert_equal ["https://made-up-link.com"], db_doc.links
    assert_equal ["Hello world!", "Click this link."], db_doc.text
    assert db_doc.respond_to? :table_text2
    assert_instance_of String, db_doc.table_text2
    assert_equal "Header TextAnother Header", db_doc.table_text2
    assert_equal :a, Wgit::Document.text_elements.delete(:a)
  end

  def test_virtual_attributes_extension_init_from_mongo_doc
    # Simulate a Wgit::Document with extensions initialized and stored in 
    # MongoDB before being retrieved as a Hash instance. Code is a virtual
    # attribute (a.k.a. an extension).
    extended_mongo_doc = {
        "url"   => "https://google.co.uk",
        "score" => 2.1,
        "title" => "Test Page 233",
        "code"  => "puts 'hello world'",
    }

    name = Wgit::Document.define_extension(:code, "//code",
      singleton: true, text_content_only: true)
    
    doc = Wgit::Document.new extended_mongo_doc
    
    assert_equal :init_code, name
    assert doc.respond_to? :code
    assert_equal extended_mongo_doc["url"], doc.url
    assert_equal extended_mongo_doc["score"], doc.score
    assert_equal extended_mongo_doc["title"], doc.title
    assert_equal extended_mongo_doc["code"], doc.code
  end

  def test_virtual_attributes_empty_singleton_value_from_html
    name = Wgit::Document.define_extension(:single, "//single",
      singleton: true, text_content_only: true)
    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p><table><th>Header Text</th>\
<th>Another Header</th></table></html>"
    )
    
    assert_equal :init_single, name
    assert doc.respond_to? :single
    assert_nil doc.single
  end

  def test_virtual_attributes_empty_array_value_from_html
    name = Wgit::Document.define_extension(:array, "//array",
      singleton: false, text_content_only: true)
    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p><table><th>Header Text</th>\
<th>Another Header</th></table></html>"
    )
    
    assert_equal :init_array, name
    assert doc.respond_to? :array
    assert_equal [], doc.array
  end

  def test_virtual_attributes_empty_singleton_value_from_obj
    name = Wgit::Document.define_extension(:single2, "//single",
      singleton: true, text_content_only: true)
    
    doc = Wgit::Document.new({
      "url" => "https://google.co.uk"
    })
    
    assert_equal :init_single2, name
    assert doc.respond_to? :single2
    assert_nil doc.single2
  end

  def test_virtual_attributes_empty_array_value_from_obj
    name = Wgit::Document.define_extension(:array2, "//array",
      singleton: false, text_content_only: true)
    
    doc = Wgit::Document.new({
      "url" => "https://google.co.uk"
    })
    
    assert_equal :init_array2, name
    assert doc.respond_to? :array2
    assert_equal [], doc.array2
  end

  def test_remove_extension_success
    Wgit::Document.define_extension(:blah, "//blah")
    assert Wgit::Document.remove_extension(:blah)
  end

  def test_remove_extension_failure
    # blah2 doesn't exist so false should be returned.
    refute Wgit::Document.remove_extension(:blah2)
  end
end
