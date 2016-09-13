require "minitest/autorun"
require 'minitest/pride'
require_relative "helpers/test_helper"
require_relative "../lib/wgit/core_ext"
require_relative "../lib/wgit/document"
require_relative "../lib/wgit/database/database"
require_relative "../lib/wgit/database/database_helper"

require "byebug"

# @author Michael Telford
# Tests the ability to extend the Wgit::Document functionality. 
# WARNING: Certain tests will clear down the DB prior to the test run.
class TestDocumentExtension < Minitest::Test
  include TestHelper
  include Wgit::DatabaseHelper
  
  # Runs before every test.
  def setup
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
  end
  
  def test_virtual_attributes_extension_with_defaults
    # Test default scenario - true and text_content_only: true
    Wgit::Document.define_extension(:table_text, "//table", 
                                    singleton: true, text_content_only: true)
    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p><table><th>Header Text</th>\
<th>Another Header</th></table></html>"
    )
    
    assert doc.respond_to? :table_text
    table_text = doc.table_text
    
    assert_instance_of String, table_text
    assert_equal "Header TextAnother Header", table_text
  end
  
  def test_virtual_attributes_extension_with_non_defaults
    # Test singleton: false and text_content_only: false
    Wgit::Document.define_extension(:tables, "//table", 
                                    singleton: false, text_content_only: false)
    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p>\
<table><th>Header Text</th><th>Another Header</th></table></html>"
    )
    
    assert doc.respond_to? :tables
    tables = doc.tables
    
    assert_instance_of Nokogiri::XML::NodeSet, tables
    assert_equal 1, tables.length
    
    assert_instance_of Nokogiri::XML::Element, tables.first
  end
  
  def test_virtual_attributes_extension_init_from_database
    clear_db
    
    # Define a text and virtual attribute extension. 
    Wgit::Document.text_elements << :a
    Wgit::Document.define_extension(:table_text, "//table", 
                                    singleton: true, text_content_only: true)
                                    
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p>\
<a href='https://made-up-link.com'>Click this link.</a>\
<table><th>Header Text</th><th>Another Header</th></table></html>"
    )
    
    # Some basic Document assertions before the database interactions. 
    assert ["https://made-up-link.com"], doc.links
    assert doc.respond_to? :table_text
    assert_equal "Header TextAnother Header", doc.table_text
    
    db = Wgit::Database.new
    db.insert doc # Uses Document#to_h and Model.document. 
    
    assert doc?({
      :url => "http://some_url.com",
      :score => 0.0,
      :title => nil,
      :author => nil,
      :keywords => nil,
      :links => ["https://made-up-link.com"],
      :text => ["Hello world!", "Click this link."],
      :table_text => "Header TextAnother Header"
    })
    
    results = db.search "Hello world"
    assert results.length == 1
    
    db_doc = results.first
    refute_equal doc.object_id, db_doc.object_id
    
    assert_instance_of Wgit::Document, db_doc
    assert_equal "http://some_url.com", db_doc.url
    assert ["https://made-up-link.com"], db_doc.links
    assert ["Hello world!", "Click this link."], db_doc.text
    assert db_doc.respond_to? :table_text
    assert_instance_of String, db_doc.table_text
    assert_equal "Header TextAnother Header", db_doc.table_text
  end
  
  # Runs after every test.
  def teardown
    # We load document.rb after each test to remove any extensions added so as 
    # not to affect subsequent tests.  
    load "./lib/wgit/document.rb"
  end
end
