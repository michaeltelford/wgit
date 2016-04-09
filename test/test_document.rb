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
                "security.html",
                "about.html",
                "http://www.yahoo.com",
                "/contact.html",
                "http://www.bing.com",
                "tests.html",
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
        @stats = {
            :url => 25, 
            :html => 929, 
            :title => 15, 
            :author => 15, 
            :keywords => 3, 
            :links => 9, 
            :text_length => 4, 
            :text_bytes => 281
        }
        @search_results = [
            "Minitest rocks!! It's simplicity and power matches the Ruby \
language in which it", 
            "s primarily for testing the Ruby code used in Pinch with the \
Minitest framework."
        ]
    end
    
    def test_initialize_without_html
        doc = Document.new @url
        assert_equal @url, doc.url
        assert_empty doc.html
    end
    
    def test_initialize_with_html
        doc = Document.new @url, @html
        assert_doc doc
        assert_equal 0.0, doc.score
    end
    
    def test_initialize_with_mongo_doc
        doc = Document.new @mongo_doc_dup
        assert_doc doc
        assert_equal @mongo_doc_dup[:score], doc.score
    end
    
    def test_internal_links
        doc = Document.new @url, @html
        assert_equal [
            "security.html",
            "about.html",
            "/contact.html",
            "tests.html",
            "/contents"
        ], doc.internal_links
    end
    
    def test_internal_full_links
        doc = Document.new @url, @html
        assert_equal [
            "#{@url}/security.html",
            "#{@url}/about.html",
            "#{@url}/contact.html",
            "#{@url}/tests.html",
            "#{@url}/contents"
        ], doc.internal_full_links
    end
    
    def test_external_links
        doc = Document.new @url, @html
        assert_equal [
            "http://www.google.co.uk",
            "http://www.yahoo.com",
            "http://www.bing.com",
            "https://duckduckgo.com",
        ], doc.external_links
    end
    
    def test_stats
        doc = Document.new @url, @html
        assert_equal @stats, doc.stats
    end
    
    def test_size
        doc = Document.new @url, @html
        assert_equal @stats[:html], doc.size
    end
    
    def test_to_h
        doc = Document.new @url, @html
        hash = @mongo_doc_dup.dup
        hash[:score] = 0.0
        assert_equal hash, doc.to_h(true)
        
        hash.delete(:html)
        assert_equal hash, doc.to_h
        
        doc = Document.new @mongo_doc_dup
        hash[:score] = @mongo_doc_dup[:score]
        assert_equal hash, doc.to_h
    end
    
    def test_empty?
        doc = Document.new @url, @html
        refute doc.empty?
        
        @mongo_doc_dup.delete(:html)
        doc = Document.new @mongo_doc_dup
        assert doc.empty?
    end
    
    def test_search
        doc = Document.new @url, @html
        results = doc.search("minitest")
        assert_equal @search_results, results
    end
    
    def test_search!
        doc = Document.new @url, @html
        doc.search!("minitest")
        assert_equal @search_results, doc.text
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
