require_relative 'helpers/test_helper'

# Test class for the Document methods.
class TestDocument < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup
    @doc_url = Wgit::Url.new('http://www.mytestsite.com/home')
    @domain = Wgit::Url.new('http://www.mytestsite.com')
    @rel_base_url = '/public'
    @base_url = 'http://server.com' + @rel_base_url
    @html = File.read('test/mock/fixtures/test_doc.html')
    @mongo_doc_dup = {
      'url' => @doc_url.to_s,
      'html' => @html,
      'score' => 12.05,
      'base' => nil, # Set if using html_with_base.
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
        'Howdy!', "Welcome to my site, I hope you like what you \
see and enjoy browsing the various randomness.", "This page is \
primarily for testing the Ruby code used in Wgit with the \
Minitest framework.", "Minitest rocks!! It's simplicity \
and power matches the Ruby language in which it's developed."
      ]
    }
    @stats = {
      url: 30,
      html: 2317,
      title: 15,
      author: 15,
      keywords: 3,
      links: 20,
      text_snippets: 4,
      text_bytes: 280
    }
    @search_results = [
      "Minitest rocks!! It's simplicity and power matches the Ruby \
language in which it",
      "is primarily for testing the Ruby code used in Wgit with the \
Minitest framework."
    ]
  end

  def test_initialize__without_html
    doc = Wgit::Document.new @doc_url

    assert_equal @doc_url, doc.url
    assert_instance_of Wgit::Url, doc.url
    assert_empty doc.html
    assert_equal 0.0, doc.score
    assert_nil doc.base
  end

  def test_initialize__with_html
    doc = Wgit::Document.new @doc_url, @html

    assert_doc doc
    assert_equal 0.0, doc.score
    assert_nil doc.base
  end

  def test_initialize__with_base
    html = html_with_base @base_url
    doc = Wgit::Document.new @doc_url, html

    assert_doc doc, html: html
    assert_equal 0.0, doc.score
    assert_equal @base_url, doc.base
  end

  def test_initialize__with_mongo_doc
    doc = Wgit::Document.new @mongo_doc_dup

    assert_doc doc
    assert_equal @mongo_doc_dup['score'], doc.score
    assert_nil doc.base
  end

  def test_internal_links
    doc = Wgit::Document.new @doc_url, @html
    assert_internal_links doc

    doc = Wgit::Document.new @domain, @html
    assert_internal_links doc

    doc = Wgit::Document.new @doc_url, '<p>Hello World!</p>'
    assert_empty doc.internal_links
  end

  def test_internal_full_links
    doc = Wgit::Document.new @doc_url, @html
    assert_equal [
      "#{@doc_url}#welcome",
      "#{@doc_url}?foo=bar",
      "#{@domain}/security.html",
      "#{@domain}/about.html",
      "#{@domain}/",
      "#{@domain}/contact.html",
      "#{@domain}/tests.html",
      "#{@domain}/blog#about-us",
      "#{@domain}/contents"
    ], doc.internal_full_links
    assert doc.internal_full_links.all? do |link|
      link.instance_of?(Wgit::Url)
    end

    doc = Wgit::Document.new @domain, @html
    assert_equal [
      "#{@domain}#welcome",
      "#{@domain}?foo=bar",
      "#{@domain}/security.html",
      "#{@domain}/about.html",
      "#{@domain}/",
      "#{@domain}/contact.html",
      "#{@domain}/tests.html",
      "#{@domain}/blog#about-us",
      "#{@domain}/contents"
    ], doc.internal_full_links
    assert doc.internal_full_links.all? do |link|
      link.instance_of?(Wgit::Url)
    end

    doc = Wgit::Document.new @doc_url, '<p>Hello World!</p>'
    assert_empty doc.internal_full_links
  end

  def test_internal_full_links__with_base
    html = html_with_base @base_url
    doc = Wgit::Document.new @doc_url, html

    assert_equal [
      "#{@base_url}#welcome",
      "#{@base_url}?foo=bar",
      "#{@base_url}/security.html",
      "#{@base_url}/about.html",
      "#{@base_url}/",
      "#{@base_url}/contact.html",
      "#{@base_url}/tests.html",
      "#{@base_url}/blog#about-us",
      "#{@base_url}/contents"
    ], doc.internal_full_links
    assert doc.internal_full_links.all? do |link|
      link.instance_of?(Wgit::Url)
    end

    html = html_with_base @rel_base_url
    doc = Wgit::Document.new @doc_url, html
    expected_base = @domain + @rel_base_url

    assert_equal [
      "#{expected_base}#welcome",
      "#{expected_base}?foo=bar",
      "#{expected_base}/security.html",
      "#{expected_base}/about.html",
      "#{expected_base}/",
      "#{expected_base}/contact.html",
      "#{expected_base}/tests.html",
      "#{expected_base}/blog#about-us",
      "#{expected_base}/contents"
    ], doc.internal_full_links
    assert doc.internal_full_links.all? do |link|
      link.instance_of?(Wgit::Url)
    end
  end

  def test_external_links
    doc = Wgit::Document.new @doc_url, @html
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

    doc = Wgit::Document.new @doc_url, '<p>Hello World!</p>'
    assert_empty doc.external_links
  end

  def test_stats
    doc = Wgit::Document.new @doc_url, @html
    assert_equal @stats, doc.stats
  end

  def test_size
    doc = Wgit::Document.new @doc_url, @html
    assert_equal @stats[:html], doc.size
  end

  def test_to_h
    doc = Wgit::Document.new @doc_url, @html
    hash = @mongo_doc_dup.dup
    hash['score'] = 0.0
    assert_equal hash, doc.to_h(true)

    hash.delete('html')
    assert_equal hash, doc.to_h

    doc = Wgit::Document.new @mongo_doc_dup
    hash = @mongo_doc_dup.dup
    hash.delete('html')
    assert_equal hash, doc.to_h

    html = html_with_base @base_url
    doc = Wgit::Document.new @doc_url, html
    hash = @mongo_doc_dup.dup
    hash.delete('html')
    hash['score'] = 0.0
    hash['base'] = @base_url
    assert_equal hash, doc.to_h
  end

  def test_to_json
    doc = Wgit::Document.new @doc_url, @html
    refute doc.to_json.empty?
    refute doc.to_json(true).empty?
  end

  def test_double_equals
    doc = Wgit::Document.new @doc_url, @html
    refute doc == Object.new
    assert doc == doc.clone
    refute doc.object_id == doc.clone.object_id
    refute doc == Wgit::Document.new(Wgit::Url.new("#{@domain}/index"), @html)
    refute doc == Wgit::Document.new(@domain, "#{@html}<?php echo 'Hello' ?>")
  end

  def test_square_brackets
    range = 0..50
    doc = Wgit::Document.new @doc_url, @html
    assert_equal @html[range], doc[range]
  end

  def test_date_crawled
    timestamp = Time.now
    url = Wgit::Url.new 'http://www.mytestsite.com', true, timestamp
    doc = Wgit::Document.new url
    assert_equal timestamp, doc.date_crawled
  end

  def test_base_url__no_base
    doc = Wgit::Document.new @doc_url, @html

    base = doc.base_url
    assert_equal @domain, base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('?q=hello')
    assert_equal @doc_url, base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('#top')
    assert_equal @doc_url, base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('/about')
    assert_equal @domain, base
    assert_instance_of Wgit::Url, base

    assert_raises(RuntimeError) do
      base = doc.base_url link: Wgit::Url.new('http://example.com/about')
    end
  end

  def test_base_url__absolute_base
    html = html_with_base @base_url
    doc = Wgit::Document.new @doc_url, html

    base = doc.base_url
    assert_equal @base_url, base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('?q=hello')
    assert_equal @base_url, base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('#top')
    assert_equal @base_url, base
    assert_instance_of Wgit::Url, base

    base = doc.base_url link: Wgit::Url.new('/about')
    assert_equal @base_url, base
    assert_instance_of Wgit::Url, base

    assert_raises(RuntimeError) do
      base = doc.base_url link: Wgit::Url.new('http://example.com/about')
    end
  end

  def test_base_url__relative_base
    expected_base = @domain + @rel_base_url

    html = html_with_base @rel_base_url
    doc = Wgit::Document.new @doc_url, html

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

    assert_raises(RuntimeError) do
      base = doc.base_url link: Wgit::Url.new('http://example.com/about')
    end
  end

  def test_base_url__no_base_query_string
    url  = 'http://test-site.com/public/records?q=username'.to_url
    link = '?foo=bar'.to_url

    doc = Wgit::Document.new url, @html
    base = doc.base_url link: link

    assert_equal 'http://test-site.com/public/records', base
    assert_instance_of Wgit::Url, base
  end

  def test_base_url__no_base_anchor
    url  = 'http://test-site.com/public/records#top'.to_url
    link = '#bottom'.to_url

    doc = Wgit::Document.new url, @html
    base = doc.base_url link: link

    assert_equal 'http://test-site.com/public/records', base
    assert_instance_of Wgit::Url, base
  end

  def test_empty?
    doc = Wgit::Document.new @doc_url, @html
    refute doc.empty?

    @mongo_doc_dup.delete('html')
    doc = Wgit::Document.new @mongo_doc_dup
    assert doc.empty?

    doc = Wgit::Document.new @doc_url, nil
    assert doc.empty?
  end

  def test_search
    doc = Wgit::Document.new @doc_url, @html
    results = doc.search('minitest', 80)
    assert_equal @search_results, results
  end

  def test_search!
    doc = Wgit::Document.new @doc_url, @html
    orig_text = doc.text
    assert_equal orig_text, doc.search!('minitest', 80)
    assert_equal @search_results, doc.text
  end

  def test_xpath
    doc = Wgit::Document.new @doc_url, @html
    results = doc.xpath('//title')
    assert_equal @mongo_doc_dup['title'], results.first.content
  end

  def test_css
    doc = Wgit::Document.new @doc_url, @html
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
    assert_equal @doc_url, doc.url
    assert_instance_of Wgit::Url, doc.url
    assert_equal html, doc.html
    assert_equal @mongo_doc_dup['title'], doc.title
    assert_equal @mongo_doc_dup['author'], doc.author
    assert_equal @mongo_doc_dup['keywords'], doc.keywords
    assert_equal @mongo_doc_dup['links'], doc.links
    assert doc.links.all? { |link| link.instance_of? Wgit::Url }
    assert_equal @mongo_doc_dup['text'], doc.text
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
