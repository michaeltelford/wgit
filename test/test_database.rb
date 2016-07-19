require "minitest/autorun"
require_relative "test_helper"
require_relative "test_database_helper"

# @author Michael Telford
class TestDocument < Minitest::Test
  include TestHelper
  include TestDatabaseHelper
  
  def setup
    # Runs before every test.
    @url = {
      #
    }
    @html = File.read("test/test_doc.html")
    @doc = { 
      :url => "http://www.mytestsite.com", 
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
end
