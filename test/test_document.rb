require "minitest/autorun"
require_relative "test_helper"
require_relative "../lib/pinch/url"
require_relative "../lib/pinch/document"

# @author Michael Telford
class TestDocument < Minitest::Test
    include TestHelper
    
    def setup
        # Runs before every test.
        @url = Url.new("http://www.mytestsite.com")
        @html = File.read("test/test_doc.html")
        @mongo_doc_dup = { 
            :url => @url, 
            :html => @html,
            :title => "My Test Webpage",
            :author => "Michael Telford",
            :keywords => ["Minitest", "Ruby", "Test Document"],
            :links => [
                "http://www.google.co.uk",
                "about.html",
                "http://www.yahoo.com",
                "/contact.html",
                "http://www.bing.com",
                "http://www.mytestsite.com/tests.html",
                "https://duckduckgo.com",
                "/contents"
            ],
            :text => [
                "Howdy!", "Welcome to my site, I hope you like what you \
see and enjoy browsing the various randomness.", "This page is \
primarily for testing the Ruby code used in Pinch with the \
Minitest framework.", "Minitest rocks!! It's simplicity \
and power matches the Ruby language in which it's developed."
            ],
            :score => 12.05
        }
    end
    
    def test_document_initialize_without_html
        doc = nil
        flunk_ex self do
            doc = Document.new @url
        end
        assert_equal @url, doc.url
        assert_empty doc.html
    end
    
    def test_document_initialize_with_html
        doc = nil
        flunk_ex self do
            doc = Document.new @url, @html
        end
        assert_doc(doc)
        assert_nil doc.score
    end
    
    def test_document_initialize_with_mongo_doc
        doc = nil
        flunk_ex self do
            doc = Document.new @mongo_doc_dup
        end
        assert_doc(doc)
        assert_equal @mongo_doc_dup[:score], doc.score
    end
    
    def test_document_internal_links
        doc = Document.new @url, @html
        assert_equal [
            "about.html",
            "/contact.html",
            "tests.html",
            "/contents"
        ], doc.internal_links
    end
    
    private
    
    def assert_doc(doc)
        assert_equal @url, doc.url
        assert_equal @html, doc.html
        assert_equal @mongo_doc_dup[:title], doc.title
        assert_equal @mongo_doc_dup[:author], doc.author
        assert_equal @mongo_doc_dup[:keywords], doc.keywords
        assert_equal @mongo_doc_dup[:links], doc.links
        assert_equal @mongo_doc_dup[:text], doc.text
    end
end
