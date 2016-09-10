require "minitest/autorun"
require 'minitest/pride'
require_relative "helpers/test_helper"
require_relative "../lib/wgit/core_ext"
require_relative "../lib/wgit/document"

require "byebug"

### Any Document extensions must be done outside of a def. ###
module Wgit
  class Document
    # Text elements extension. 
    @@text_elements << :a
    
    private
    
    # Virtual attributes extension. 
    def init_tables
      @tables = nil
      xpath = "//table"
      singleton = false
      text_content = true # text or Nokogiri object.

      init_var :@tables, xpath, singleton, text_content
    end
  end
end

# @author Michael Telford
class TestDocumentExtension < Minitest::Test
  include TestHelper
  
  # Runs before every test.
  def setup
  end
  
  # Extends the text elements by processing <a> tags and adds the tag text 
  # into Document#text. 
  def test_text_elements_extension
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p><a href='https://made-up-link.com'>Click this link.</a></html>"
    )

    assert ["https://made-up-link.com"], doc.links
    assert ["Hello world!", "Click this link."], doc.text
  end
  
  def test_virtual_attributes_extension
    doc = Wgit::Document.new(
      "http://some_url.com".to_url, 
      "<html><p>Hello world!</p><table><th>Header Text</th></table></html>"
    )
    
    assert doc.respond_to? :tables
    tables = doc.tables
    
    assert_instance_of Array, tables
    assert_equal 1, tables.length
    assert_equal "Header Text", tables.first
  end
  
  def test_virtual_attributes_extension_init_from_database
    skip
  end
end

# TODO: Remove the Document extensions here.
