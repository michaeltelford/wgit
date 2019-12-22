require_relative 'helpers/test_helper'

# Test class for the Document methods.
class TestDocument < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup
    @html = File.read('test/mock/fixtures/test_doc.html')
    @mongo_doc_dup = {
      'url' => {
        'url' => 'http://www.mytestsite.com/home',
        'crawled' => true,
        'date_crawled' => '2016-04-20 14:33:16 +0100',
        'crawl_duration' => 0.42446
      },
      'html' => @html,
      'score' => 12.05,
      'base' => nil, # Gets set if using html_with_base.
      'title' => 'My Test Webpage',
      'author' => 'Michael Telford',
      'keywords' => ['Minitest', 'Ruby', 'Test Document'],
      'links' => [
        '#welcome',
        '?foo=bar',
        'http://www.google.co.uk',
        'http://www.mytestsite.com/security.html',
        '/about.html',
        'about.html/',
        '/',
        'http://www.yahoo.com',
        '/contact.html',
        'http://www.bing.com/',
        'http://www.mytestsite.com',
        'http://www.mytestsite.com/',
        'http://www.mytestsite.com/tests.html',
        'https://duckduckgo.com/search?q=hello&page=2',
        '/blog#about-us',
        'https://example.com/blog#about-us',
        '/contents/',
        'http://ftp.mytestsite.com',
        'http://ftp.mytestsite.com/',
        'http://ftp.mytestsite.com/files'
      ],
      'text' => [
        'My Test Webpage', 'Howdy!', 'Welcome', 'Foo Bar', 'Google', 'Security', 'Welcome to my site, I hope you like what you see and enjoy browsing the various randomness.', 'About', 'About 2', 'Index', 'This page is primarily for testing the Ruby code used in Wgit with the Minitest framework.', "Minitest rocks!! It's simplicity and power matches the Ruby language in which it's developed.", 'Yahoo', 'Contact', 'Bing', 'Index 2', 'Index 3', 'Tests', 'Duck Duck Go', 'Blog', 'Example.com Blog', 'Contents', 'Same Domain FTP Server', 'Same Domain FTP Server 2', 'Same Domain FTP Server Files'
      ]
    }
    @stats = {
      url: 30,
      html: 2317,
      title: 15,
      author: 15,
      keywords: 3,
      links: 20,
      text_snippets: 25,
      text_bytes: 489
    }
  end

  def test_initialize__without_html
    time = Time.now - 1000
    url = Wgit::Url.new(
      'http://www.mytestsite.com/home',
      crawled: true,
      date_crawled: time,
      crawl_duration: 0.3445
    )
    doc = Wgit::Document.new url

    assert_doc doc, html: nil
    assert_equal time.to_s, doc.url.date_crawled.to_s
    assert_equal 0.3445, doc.url.crawl_duration
    assert_equal 0.0, doc.score
    assert_nil doc.base
  end

  def test_initialize__with_string_url_and_nil_html
    doc = Wgit::Document.new 'http://www.mytestsite.com/home', nil

    assert_doc doc, html: nil
    assert_nil doc.url.crawl_duration
    assert_equal 0.0, doc.score
    assert_nil doc.base
  end

  def test_initialize__with_html
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html

    assert_doc doc
    assert_nil doc.url.crawl_duration
    assert_equal 0.0, doc.score
    assert_nil doc.base
  end

  def test_initialize__with_base
    html = html_with_base 'http://server.com/public'
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, html

    assert_doc doc, html: html
    assert_nil doc.url.crawl_duration
    assert_equal 0.0, doc.score
    assert_equal 'http://server.com/public', doc.base
  end

  def test_initialize__with_mongo_doc
    doc = Wgit::Document.new @mongo_doc_dup

    assert_doc doc
    assert_equal '2016-04-20 14:33:16 +0100', doc.url.date_crawled
    assert_equal 0.42446, doc.url.crawl_duration
    assert_equal @mongo_doc_dup['score'], doc.score
    assert_nil doc.base
  end

  def test_internal_links
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    assert_internal_links doc

    doc = Wgit::Document.new 'http://www.mytestsite.com'.to_url, @html
    assert_internal_links doc

    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, '<p>Hello World!</p>'
    assert_empty doc.internal_links
  end

  def test_internal_absolute_links
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    assert_equal [
      'http://www.mytestsite.com/home#welcome',
      'http://www.mytestsite.com/home?foo=bar',
      'http://www.mytestsite.com/security.html',
      'http://www.mytestsite.com/about.html',
      'http://www.mytestsite.com/',
      'http://www.mytestsite.com/contact.html',
      'http://www.mytestsite.com/tests.html',
      'http://www.mytestsite.com/blog#about-us',
      'http://www.mytestsite.com/contents'
    ], doc.internal_absolute_links
    assert doc.internal_absolute_links.all? do |link|
      link.instance_of?(Wgit::Url)
    end

    doc = Wgit::Document.new 'http://www.mytestsite.com'.to_url, @html
    assert_equal [
      'http://www.mytestsite.com#welcome',
      'http://www.mytestsite.com?foo=bar',
      'http://www.mytestsite.com/security.html',
      'http://www.mytestsite.com/about.html',
      'http://www.mytestsite.com/',
      'http://www.mytestsite.com/contact.html',
      'http://www.mytestsite.com/tests.html',
      'http://www.mytestsite.com/blog#about-us',
      'http://www.mytestsite.com/contents'
    ], doc.internal_absolute_links
    assert doc.internal_absolute_links.all? do |link|
      link.instance_of?(Wgit::Url)
    end

    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, '<p>Hello World!</p>'
    assert_empty doc.internal_absolute_links
  end

  def test_internal_absolute_links__with_base
    html = html_with_base 'http://server.com/public'
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, html

    assert_equal [
      'http://server.com/public#welcome',
      'http://server.com/public?foo=bar',
      'http://server.com/public/security.html',
      'http://server.com/public/about.html',
      'http://server.com/public/',
      'http://server.com/public/contact.html',
      'http://server.com/public/tests.html',
      'http://server.com/public/blog#about-us',
      'http://server.com/public/contents'
    ], doc.internal_absolute_links
    assert doc.internal_absolute_links.all? do |link|
      link.instance_of?(Wgit::Url)
    end

    html = html_with_base '/public'
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, html

    assert_equal [
      'http://www.mytestsite.com/public#welcome',
      'http://www.mytestsite.com/public?foo=bar',
      'http://www.mytestsite.com/public/security.html',
      'http://www.mytestsite.com/public/about.html',
      'http://www.mytestsite.com/public/',
      'http://www.mytestsite.com/public/contact.html',
      'http://www.mytestsite.com/public/tests.html',
      'http://www.mytestsite.com/public/blog#about-us',
      'http://www.mytestsite.com/public/contents'
    ], doc.internal_absolute_links
    assert doc.internal_absolute_links.all? do |link|
      link.instance_of?(Wgit::Url)
    end
  end

  def test_external_links
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    assert_equal [
      'http://www.google.co.uk',
      'http://www.yahoo.com',
      'http://www.bing.com',
      'https://duckduckgo.com/search?q=hello&page=2',
      'https://example.com/blog#about-us',
      'http://ftp.mytestsite.com',
      'http://ftp.mytestsite.com/files'
    ], doc.external_links
    assert doc.external_links.all? { |link| link.instance_of?(Wgit::Url) }

    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, '<p>Hello World!</p>'
    assert_empty doc.external_links
  end

  def test_stats
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    assert_equal @stats, doc.stats
  end

  def test_size
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    assert_equal @stats[:html], doc.size
  end

  def test_to_h
    expected = @mongo_doc_dup.dup
    expected['score'] = 0.0 # A new Document score is always 0.0.
    expected['url'] = 'http://www.mytestsite.com/home' # The to_h url is just a string.

    # Test new Document from Strings with included html.
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    assert_equal expected, doc.to_h(include_html: true)

    # Test new Document from Strings with excluded html.
    expected.delete('html')
    assert_equal expected, doc.to_h

    # Test new Document from Object with excluded html.
    doc = Wgit::Document.new @mongo_doc_dup.dup
    expected['score'] = 12.05
    assert_equal expected, doc.to_h

    # Test new Document from Strings including base with excluded html.
    html = html_with_base 'http://server.com/public'
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, html
    expected['score'] = 0.0
    expected['base'] = 'http://server.com/public'
    assert_equal expected, doc.to_h

    # Test new Document from Strings with included html.
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    expected.delete('score')
    expected['base'] = nil
    assert_equal expected, doc.to_h(include_score: false)
  end

  def test_to_json
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    refute doc.to_json.empty?
    refute doc.to_json(include_html: true).empty?
  end

  def test_double_equals
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    refute doc == Object.new
    assert doc == doc.clone
    refute doc.object_id == doc.clone.object_id
    refute doc == Wgit::Document.new(Wgit::Url.new('http://www.mytestsite.com/index'), @html)
    refute doc == Wgit::Document.new('http://www.mytestsite.com'.to_url, "#{@html}<?php echo 'Hello' ?>")
  end

  def test_square_brackets
    range = 0..50
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    assert_equal @html[range], doc[range]
  end

  def test_date_crawled
    timestamp = Time.now
    url = Wgit::Url.new(
      'http://www.mytestsite.com',
      crawled: true,
      date_crawled: timestamp
    )
    doc = Wgit::Document.new url

    assert_equal timestamp.to_s, doc.url.date_crawled.to_s
  end

  def test_crawl_duration
    url = Wgit::Url.new(
      'http://www.mytestsite.com',
      crawled: true,
      crawl_duration: 0.9
    )
    doc = Wgit::Document.new url

    assert_equal 0.9, doc.url.crawl_duration
  end

  def test_base_url__no_base
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html

    base = doc.base_url
    assert_equal 'http://www.mytestsite.com', base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: '?q=hello'
    assert_equal 'http://www.mytestsite.com/home', base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('#top')
    assert_equal 'http://www.mytestsite.com/home', base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: '/about'
    assert_equal 'http://www.mytestsite.com', base
    assert_instance_of Wgit::Url, base

    # Absolute link raises an exception.
    ex = assert_raises(StandardError) do
      base = doc.base_url link: Wgit::Url.new('http://example.com/about')
    end
    assert_equal 'link must be relative: http://example.com/about', ex.message

    # Relative doc @url raises an exception.
    doc = Wgit::Document.new '/home'
    ex = assert_raises(StandardError) do
      base = doc.base_url link: '/about'
    end
    assert_equal "Document @url ('/home') cannot be relative if <base> is nil", ex.message
  end

  def test_base_url__absolute_base
    html = html_with_base 'http://server.com/public'
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, html

    base = doc.base_url
    assert_equal 'http://server.com/public', base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('?q=hello')
    assert_equal 'http://server.com/public', base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('#top')
    assert_equal 'http://server.com/public', base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('/about')
    assert_equal 'http://server.com/public', base
    assert_instance_of Wgit::Url, base

    ex = assert_raises(StandardError) do
      base = doc.base_url link: Wgit::Url.new('http://example.com/about')
    end
    assert_equal 'link must be relative: http://example.com/about', ex.message

    # Document with relative @url and absolute <base>.
    doc = Wgit::Document.new '/home', html
    base = doc.base_url link: '/about'
    assert_equal 'http://server.com/public', base
    assert_instance_of Wgit::Url, base
  end

  def test_base_url__relative_base
    expected_base = 'http://www.mytestsite.com/public'

    html = html_with_base '/public'
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, html

    base = doc.base_url
    assert_equal expected_base, base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('?q=hello')
    assert_equal expected_base, base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('#top')
    assert_equal expected_base, base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('/about')
    assert_equal expected_base, base
    assert_instance_of Wgit::Url, base

    ex = assert_raises(StandardError) do
      base = doc.base_url link: Wgit::Url.new('http://example.com/about')
    end
    assert_equal 'link must be relative: http://example.com/about', ex.message

    # Document with relative @url and relative <base>.
    doc = Wgit::Document.new '/home', html
    ex = assert_raises(StandardError) do
      base = doc.base_url link: '/about'
    end
    assert_equal "Document @url ('/home') and <base> ('/public') both can't be relative", ex.message
  end

  def test_base_url__no_base__query_string
    url  = 'http://test-site.com/public/records?q=username'.to_url
    link = '?foo=bar'.to_url

    doc = Wgit::Document.new url, @html
    base = doc.base_url link: link

    assert_equal 'http://test-site.com/public/records', base
    assert_instance_of Wgit::Url, base
  end

  def test_base_url__no_base__fragment
    url  = 'http://test-site.com/public/records#top'.to_url
    link = '#bottom'.to_url

    doc = Wgit::Document.new url, @html
    base = doc.base_url link: link

    assert_equal 'http://test-site.com/public/records', base
    assert_instance_of Wgit::Url, base
  end

  def test_empty?
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    refute doc.empty?

    @mongo_doc_dup.delete('html')
    doc = Wgit::Document.new @mongo_doc_dup
    assert doc.empty?

    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, nil
    assert doc.empty?
  end

  def test_search
    doc = Wgit::Document.new 'http://www.mytestsite.com/home', @html

    # Test case_sensitive: false.
    results = doc.search('minitest', case_sensitive: false)
    assert_equal([
      "Minitest rocks!! It's simplicity and power matches the Ruby \
language in which it",
      "is primarily for testing the Ruby code used in Wgit with the \
Minitest framework."
    ], results)

    # Test case_sensitive: true.
    assert_empty doc.search('minitest', case_sensitive: true)

    # Test whole_sentence: false.
    results = doc.search('used code', whole_sentence: false)
    assert_equal([
      " page is primarily for testing the Ruby code used in Wgit with the Minitest fram"
    ], results)

    # Test whole_sentence: true.
    assert_empty doc.search('used code', whole_sentence: true)

    # Test case_sensitive: false, whole_sentence: true with exact words.
    results = doc.search('coDe usEd', whole_sentence: true)
    assert_equal([
      " page is primarily for testing the Ruby code used in Wgit with the Minitest fram"
    ], results)

    # Test case_sensitive: true, whole_sentence: true with exact words.
    assert_empty doc.search('coDe usEd', case_sensitive: true, whole_sentence: true)
  end

  def test_search!
    doc = Wgit::Document.new 'http://www.mytestsite.com/home', @html
    orig_text = doc.text

    assert_equal orig_text, doc.search!('minitest', sentence_limit: 16)
    assert_equal(['Minitest rocks!!', 'ith the Minitest'], doc.text)
  end

  def test_xpath
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    results = doc.xpath('//title')
    assert_equal @mongo_doc_dup['title'], results.first.content
  end

  def test_css
    doc = Wgit::Document.new 'http://www.mytestsite.com/home'.to_url, @html
    results = doc.css('title')
    assert_equal @mongo_doc_dup['title'], results.first.content
  end

  private

  # Inserts a <base> element into @html.
  def html_with_base(href)
    noko_doc = Nokogiri::HTML @html
    title_el = noko_doc.at 'title'
    title_el.add_next_sibling "<base href='#{href}'>"
    noko_doc.to_html
  end

  # We can override the doc's expected html for different test scenarios.
  def assert_doc(doc, html: @html)
    assert_equal 'http://www.mytestsite.com/home'.to_url, doc.url
    assert_instance_of Wgit::Url, doc.url
    assert doc.url.crawled
    refute_nil doc.url.date_crawled

    if html && !html.empty?
      assert_equal html, doc.html
      assert_equal @mongo_doc_dup['title'], doc.title
      assert_equal @mongo_doc_dup['author'], doc.author
      assert_equal @mongo_doc_dup['keywords'], doc.keywords
      assert_equal @mongo_doc_dup['links'], doc.links
      assert doc.links.all? { |link| link.instance_of? Wgit::Url }
      assert_equal @mongo_doc_dup['text'], doc.text
    else
      assert_empty doc.html
      assert_nil doc.title
      assert_nil doc.author
      assert_nil doc.keywords
      assert_empty doc.links
      assert_empty doc.text
    end
  end

  def assert_internal_links(doc)
    assert_equal [
      '#welcome',
      '?foo=bar',
      'security.html',
      'about.html',
      '/',
      'contact.html',
      'tests.html',
      'blog#about-us',
      'contents'
    ], doc.internal_links
    assert doc.internal_links.all? { |link| link.instance_of?(Wgit::Url) }
  end
end
