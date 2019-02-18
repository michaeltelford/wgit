require_relative "helpers/test_helper"

# Test class for the Document methods.
class TestDocument < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!
  
  # Runs before every test.
  def setup
    @url = Wgit::Url.new("http://www.mytestsite.com")
    @html = File.read("test/helpers/test_doc.html")
    @mongo_doc_dup = { 
      "url" => @url, 
      "html" => @html,
      "title" => "My Test Webpage",
      "author" => "Michael Telford",
      "keywords" => ["Minitest", "Ruby", "Test Document"],
      "links" => [
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
      "text" => [
        "Howdy!", "Welcome to my site, I hope you like what you \
see and enjoy browsing the various randomness.", "This page is \
primarily for testing the Ruby code used in Wgit with the \
Minitest framework.", "Minitest rocks!! It's simplicity \
and power matches the Ruby language in which it's developed."
      ],
      "score" => 12.05
    }
    @stats = {
      url: 25, 
      html: 928, 
      title: 15, 
      author: 15, 
      keywords: 3, 
      links: 9, 
      text_length: 4, 
      text_bytes: 280
    }
    @search_results = [
      "Minitest rocks!! It's simplicity and power matches the Ruby \
language in which it", 
      "is primarily for testing the Ruby code used in Wgit with the \
Minitest framework."
    ]
  end
  
  def test_initialize_without_html
    doc = Wgit::Document.new @url
    assert_equal @url, doc.url
    assert_empty doc.html
  end
  
  def test_initialize_with_html
    doc = Wgit::Document.new @url, @html
    assert_doc doc
    assert_equal 0.0, doc.score
  end
  
  def test_initialize_with_mongo_doc
    doc = Wgit::Document.new @mongo_doc_dup
    assert_doc doc
    assert_equal @mongo_doc_dup["score"], doc.score
  end
  
  def test_internal_links
    doc = Wgit::Document.new @url, @html
    assert_equal [
      "security.html",
      "about.html",
      "/contact.html",
      "tests.html",
      "/contents"
    ], doc.internal_links
    assert doc.internal_links.all? { |link| link.instance_of?(Wgit::Url) }
    
    doc = Wgit::Document.new @url, "<p>Hello World!</p>"
    assert_empty doc.internal_links
  end
  
  def test_internal_full_links
    doc = Wgit::Document.new @url, @html
    assert_equal [
      "#{@url}/security.html",
      "#{@url}/about.html",
      "#{@url}/contact.html",
      "#{@url}/tests.html",
      "#{@url}/contents"
    ], doc.internal_full_links
    assert doc.internal_full_links.all? do |link| 
      link.instance_of?(Wgit::Url)
    end
    
    doc = Wgit::Document.new @url, "<p>Hello World!</p>"
    assert_empty doc.internal_full_links
  end
  
  def test_external_links
    doc = Wgit::Document.new @url, @html
    assert_equal [
      "http://www.google.co.uk",
      "http://www.yahoo.com",
      "http://www.bing.com",
      "https://duckduckgo.com"
    ], doc.external_links
    assert doc.external_links.all? { |link| link.instance_of?(Wgit::Url) }
    
    doc = Wgit::Document.new @url, "<p>Hello World!</p>"
    assert_empty doc.external_links
  end
  
  def test_stats
    doc = Wgit::Document.new @url, @html
    assert_equal @stats, doc.stats
  end
  
  def test_size
    doc = Wgit::Document.new @url, @html
    assert_equal @stats[:html], doc.size
  end
  
  def test_to_h
    doc = Wgit::Document.new @url, @html
    hash = @mongo_doc_dup.dup
    hash["score"] = 0.0
    assert_equal hash, doc.to_h(true)
    
    hash.delete("html")
    assert_equal hash, doc.to_h
    
    doc = Wgit::Document.new @mongo_doc_dup
    hash["score"] = @mongo_doc_dup["score"]
    assert_equal hash, doc.to_h
  end

  def test_to_json
    doc = Wgit::Document.new @url, @html
    assert_equal to_json_without_html, doc.to_json
    assert_equal to_json_with_html, doc.to_json(true)
  end

  def test_double_equals
    doc = Wgit::Document.new @url, @html
    refute doc == Object.new
    assert doc == doc.clone
    refute doc.object_id == doc.clone.object_id
    refute doc == Wgit::Document.new(Wgit::Url.new("#{@url}/index"), @html)
    refute doc == Wgit::Document.new(@url, "#{@html}<?php echo 'Hello' ?>")
  end
  
  def test_square_brackets
    range = 0..50
    doc = Wgit::Document.new @url, @html
    assert_equal @html[range], doc[range]
  end

  def test_date_crawled
    timestamp = Time.now
    url = Wgit::Url.new "http://www.mytestsite.com", true, timestamp
    doc = Wgit::Document.new url
    assert_equal timestamp, doc.date_crawled
  end
  
  def test_empty?
    doc = Wgit::Document.new @url, @html
    refute doc.empty?
    
    @mongo_doc_dup.delete("html")
    doc = Wgit::Document.new @mongo_doc_dup
    assert doc.empty?

    doc = Wgit::Document.new @url, nil
    assert doc.empty?
  end
  
  def test_search
    doc = Wgit::Document.new @url, @html
    results = doc.search("minitest", 80)
    assert_equal @search_results, results
  end
  
  def test_search!
    doc = Wgit::Document.new @url, @html
    orig_text = doc.text
    assert_equal orig_text, doc.search!("minitest", 80)
    assert_equal @search_results, doc.text
  end
  
  def test_xpath
    doc = Wgit::Document.new @url, @html
    results = doc.xpath("//title")
    assert_equal @mongo_doc_dup["title"], results.first.content
  end

  def test_css
    doc = Wgit::Document.new @url, @html
    results = doc.css("title")
    assert_equal @mongo_doc_dup["title"], results.first.content
  end
  
private
  
  def assert_doc(doc)
    assert_equal @url, doc.url
    assert_equal @html, doc.html
    assert_equal @mongo_doc_dup["title"], doc.title
    assert_equal @mongo_doc_dup["author"], doc.author
    assert_equal @mongo_doc_dup["keywords"], doc.keywords
    assert_equal @mongo_doc_dup["links"], doc.links
    assert_equal @mongo_doc_dup["text"], doc.text
  end

  def to_json_without_html
    "{\"url\":\"http://www.mytestsite.com\",\"score\":0.0,\"title\":\"My Test Webpage\",\"author\":\"Michael Telford\",\"keywords\":[\"Minitest\",\"Ruby\",\"Test Document\"],\"links\":[\"http://www.google.co.uk\",\"security.html\",\"about.html\",\"http://www.yahoo.com\",\"/contact.html\",\"http://www.bing.com\",\"tests.html\",\"https://duckduckgo.com\",\"/contents\"],\"text\":[\"Howdy!\",\"Welcome to my site, I hope you like what you see and enjoy browsing the various randomness.\",\"This page is primarily for testing the Ruby code used in Wgit with the Minitest framework.\",\"Minitest rocks!! It's simplicity and power matches the Ruby language in which it's developed.\"]}"
  end

  def to_json_with_html
    "{\"url\":\"http://www.mytestsite.com\",\"html\":\"<html>\\n<head>\\n\\t<meta http-equiv=\\\"Content-type\\\" content=\\\"text/html; charset=utf-8\\\">\\n\\t<title>My Test Webpage</title>\\n\\t<meta name=\\\"author\\\" content=\\\"Michael Telford\\\">\\n\\t<meta name=\\\"keywords\\\" content=\\\"Minitest, Ruby, Test Document\\\">\\n</head>\\n<body id=\\\"main-body\\\" onload=\\\"\\\">\\n\\t<h1>Howdy!</h1>\\n\\t<a href=\\\"http://www.google.co.uk\\\">\\n\\t<a href=\\\"www.mytestsite.com/security.html\\\">\\n\\t<h2>Welcome to my site, I hope you like what you see and enjoy browsing the various randomness.</h2>\\n\\t<a href=\\\"about.html\\\">\\n\\t<p>This page is primarily for testing the Ruby code used in Wgit with the Minitest framework.</p>\\n\\t<div id=\\\"minitest\\\">\\n\\t\\tMinitest rocks!! It's simplicity and power matches the Ruby language in which it's developed.\\n\\t\\t<a href=\\\"http://www.yahoo.com\\\">\\n\\t</div>\\n\\t<a href=\\\"/contact.html\\\">\\n\\t<a href=\\\"http://www.bing.com\\\">\\n\\t<a href=\\\"http://www.mytestsite.com/tests.html\\\">\\n\\t<a href=\\\"https://duckduckgo.com\\\">\\n\\t<a href=\\\"/contents\\\">\\n</body>\\n</html>\\n\",\"score\":0.0,\"title\":\"My Test Webpage\",\"author\":\"Michael Telford\",\"keywords\":[\"Minitest\",\"Ruby\",\"Test Document\"],\"links\":[\"http://www.google.co.uk\",\"security.html\",\"about.html\",\"http://www.yahoo.com\",\"/contact.html\",\"http://www.bing.com\",\"tests.html\",\"https://duckduckgo.com\",\"/contents\"],\"text\":[\"Howdy!\",\"Welcome to my site, I hope you like what you see and enjoy browsing the various randomness.\",\"This page is primarily for testing the Ruby code used in Wgit with the Minitest framework.\",\"Minitest rocks!! It's simplicity and power matches the Ruby language in which it's developed.\"]}"
  end
end
