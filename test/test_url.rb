# frozen_string_literal: true

require_relative 'helpers/test_helper'

# Test class for Url methods.
class TestUrl < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup
    @url_str = 'http://www.google.co.uk'
    @bad_url_str = 'my_server'
    @link = '/about.html'
    @url_str_link = "#{@url_str}#{@link}"
    @url_str_anchor = "#{@url_str_link}#about-us"
    @url_str_query = "#{@url_str_link}?foo=bar"
    @iri = 'https://www.über.com/about#top'
    @time_stamp = Time.new
    @mongo_doc_dup = {
      'url' => @url_str,
      'crawled' => true,
      'date_crawled' => @time_stamp
    }
  end

  def test_initialize
    url = Wgit::Url.new @url_str
    assert_equal @url_str, url
    refute url.crawled
    assert_nil url.date_crawled
  end

  def test_initialize_from_url
    temp_url = Wgit::Url.new @url_str
    url = Wgit::Url.new temp_url
    assert_equal @url_str, url
    refute url.crawled
    assert_nil url.date_crawled
  end

  def test_initialize_from_iri
    url = Wgit::Url.new @iri
    assert_equal @iri, url
    refute url.crawled
    assert_nil url.date_crawled
  end

  def test_initialize_from_mongo_doc
    url = Wgit::Url.new @mongo_doc_dup
    assert_equal @url_str, url
    assert url.crawled
    assert_equal @time_stamp, url.date_crawled
  end

  def test_initialize_using_parse
    url = Wgit::Url.parse @url_str
    assert_equal @url_str, url
    refute url.crawled
    assert_nil url.date_crawled
  end

  def test_validate
    Wgit::Url.validate @url_str
    Wgit::Url.validate @iri
    assert_raises(RuntimeError) { Wgit::Url.validate @bad_url_str }
    assert_raises(RuntimeError) { Wgit::Url.validate '/über' }
  end

  def test_valid?
    assert Wgit::Url.valid? @url_str
    refute Wgit::Url.valid? @bad_url_str
    assert Wgit::Url.valid? @url_str_anchor
    assert Wgit::Url.valid? @iri
    refute Wgit::Url.valid? '/über'
  end

  def test_prefix_protocol
    assert_equal "https://#{@bad_url_str}", Wgit::Url.prefix_protocol(
      @bad_url_str.dup, true
    )
    assert_equal "http://#{@bad_url_str}", Wgit::Url.prefix_protocol(
      @bad_url_str.dup
    )
  end

  def test_replace__from_string
    url = Wgit::Url.new 'http://www.google.co.uk'
    new_url = url.replace '/about'

    assert_equal '/about', url
    assert_equal '/about', new_url
    assert_equal '/about', url.to_uri.to_s
  end

  def test_replace__from_url
    url = Wgit::Url.new 'http://www.google.co.uk'
    new_url = url.replace Wgit::Url.new('/about')

    assert_equal '/about', url
    assert_equal '/about', new_url
    assert_equal '/about', url.to_uri.to_s
  end

  def test_is_relative?
    # Common type URL's.
    assert Wgit::Url.new(@link).is_relative?
    refute Wgit::Url.new(@url_str).is_relative?

    # IRI's.
    assert Wgit::Url.new('/über').is_relative?
    refute Wgit::Url.new(@iri).is_relative?

    # Single slash URL's.
    assert Wgit::Url.new('/').is_relative?

    # Anchors/fragments.
    assert Wgit::Url.new('#about-us').is_relative?
    refute Wgit::Url.new(@url_str_anchor).is_relative?

    # Query string params.
    assert Wgit::Url.new('?foo=bar').is_relative?
    refute Wgit::Url.new(@url_str_query).is_relative?

    # Valid error scenarios.
    ex = assert_raises(RuntimeError) { Wgit::Url.new('').is_relative? }
    assert_equal 'Invalid link: ', ex.message
  end

  def test_is_relative__with_host
    # IRI's.
    assert Wgit::Url.new(@iri).is_relative? host: 'https://www.über.com'
    refute Wgit::Url.new(@iri).is_relative? host: 'https://www.überon.com'

    # URL's with paths (including slashes).
    assert Wgit::Url.new(@url_str_link).is_relative? host: @url_str
    assert Wgit::Url.new('https://www.google.co.uk').is_relative? host: @url_str # Diff protocol.
    refute Wgit::Url.new(@url_str_link).is_relative? host: 'http://bing.com'
    assert Wgit::Url.new(@url_str).is_relative? host: @url_str
    assert Wgit::Url.new(@url_str + '/').is_relative? host: @url_str
    assert Wgit::Url.new(@url_str + '/').is_relative? host: @url_str + '/'

    # Single slash URL's.
    assert Wgit::Url.new('/').is_relative? host: @url_str

    # Anchors/fragments.
    assert Wgit::Url.new('#about-us').is_relative? host: @url_str
    assert Wgit::Url.new(@url_str_anchor).is_relative? host: @url_str

    # Query string params.
    assert Wgit::Url.new('?foo=bar').is_relative? host: @url_str
    assert Wgit::Url.new(@url_str_query).is_relative? host: @url_str

    # URL specific.
    refute(
      Wgit::Url.new('http://www.example.com/search').is_relative?(host: 'https://ftp.example.com')
    )
    refute(
      'http://www.example.com/search'.to_url.is_relative?(host: 'https://ftp.example.com'.to_url)
    )
    refute(
      'http://www.example.com/search'.to_url.is_relative?(host: 'https://ftp.example.co.uk'.to_url)
    )
    refute(
      'https://server.example.com'.to_url.is_relative?(host: 'https://example.com/en'.to_url)
    )

    # Valid error scenarios.
    ex = assert_raises(RuntimeError) do
      Wgit::Url.new(@url_str_link).is_relative? host: 'bing.com'
    end
    assert_equal(
      'Invalid host, must be absolute and contain protocol: bing.com',
      ex.message
    )

    ex = assert_raises(RuntimeError) { Wgit::Url.new('').is_relative? }
    assert_equal 'Invalid link: ', ex.message
  end

  def test_is_relative__with_domain
    # IRI's.
    assert Wgit::Url.new(@iri).is_relative? domain: 'https://www.über.com'
    refute Wgit::Url.new(@iri).is_relative? domain: 'https://www.überon.com'

    # URL's with paths (including slashes).
    assert Wgit::Url.new(@url_str_link).is_relative? domain: @url_str
    assert Wgit::Url.new('https://www.google.co.uk').is_relative? domain: @url_str # Diff protocol.
    refute Wgit::Url.new(@url_str_link).is_relative? domain: 'http://bing.com'
    assert Wgit::Url.new(@url_str).is_relative? domain: @url_str
    assert Wgit::Url.new(@url_str + '/').is_relative? domain: @url_str
    assert Wgit::Url.new(@url_str + '/').is_relative? domain: @url_str + '/'

    # Single slash URL's.
    assert Wgit::Url.new('/').is_relative? domain: @url_str

    # Anchors/fragments.
    assert Wgit::Url.new('#about-us').is_relative? domain: @url_str
    assert Wgit::Url.new(@url_str_anchor).is_relative? domain: @url_str

    # Query string params.
    assert Wgit::Url.new('?foo=bar').is_relative? domain: @url_str
    assert Wgit::Url.new(@url_str_query).is_relative? domain: @url_str

    # URL specific.
    assert(
      Wgit::Url.new('http://www.example.com/search').is_relative?(domain: 'https://ftp.example.com')
    )
    assert(
      'http://www.example.com/search'.to_url.is_relative?(domain: 'https://ftp.example.com'.to_url)
    )
    refute(
      'http://www.example.com/search'.to_url.is_relative?(domain: 'https://ftp.example.co.uk'.to_url)
    )
    assert(
      'https://server.example.com'.to_url.is_relative?(domain: 'https://example.com/en'.to_url)
    )

    # Valid error scenarios.
    ex = assert_raises(RuntimeError) do
      Wgit::Url.new(@url_str_link).is_relative? domain: 'bing.com'
    end
    assert_equal(
      'Invalid domain, must be absolute and contain protocol: bing.com',
      ex.message
    )

    ex = assert_raises(RuntimeError) do
      Wgit::Url.new('/about').is_relative?(host: '1', domain: '2')
    end
    assert_equal 'Provide host or domain, not both', ex.message

    ex = assert_raises(RuntimeError) { Wgit::Url.new('').is_relative? }
    assert_equal 'Invalid link: ', ex.message
  end

  def test_concat
    assert_equal @url_str_link, Wgit::Url.concat(@url_str, @link)
    assert_equal @url_str_link, Wgit::Url.concat(@url_str, @link[1..-1])
    assert_equal @url_str_anchor, Wgit::Url.concat(@url_str_link, '#about-us')
    assert_equal @url_str_query, Wgit::Url.concat(@url_str_link, '?foo=bar')
    assert_equal 'https://www.über?foo=bar', Wgit::Url.concat('https://www.über', '?foo=bar')
  end

  def test_crawled=
    url = Wgit::Url.new @url_str
    url.crawled = true
    assert url.crawled
    assert url.crawled?
  end

  def test_normalise
    # Normalise an IRI.
    url = Wgit::Url.new @iri
    normalised = url.normalise

    assert_instance_of Wgit::Url, normalised
    assert_equal 'https://www.xn--ber-goa.com/about#top', normalised

    # Already normalised URL's stay the same.
    url = Wgit::Url.new 'https://www.example.com/blah#top'
    normalised = url.normalise

    assert_instance_of Wgit::Url, normalised
    assert_equal 'https://www.example.com/blah#top', normalised
  end

  def test_to_uri
    assert_equal URI::HTTP, Wgit::Url.new(@url_str).to_uri.class
    assert_equal URI::HTTPS, Wgit::Url.new('https://blah.com').to_uri.class

    uri = Wgit::Url.new(@iri).to_uri
    assert_equal URI::HTTPS, uri.class
    assert_equal 'https://www.xn--ber-goa.com/about#top', uri.to_s
  end

  def test_to_url
    url = Wgit::Url.new @url_str
    assert_equal url.object_id, url.to_url.object_id
    assert_equal url, url.to_url
    assert_equal Wgit::Url, url.to_url.class

    url = Wgit::Url.new @iri
    assert_equal url.object_id, url.to_url.object_id
    assert_equal url, url.to_url
    assert_equal Wgit::Url, url.to_url.class
  end

  def test_to_scheme
    url = Wgit::Url.new @url_str
    assert_equal 'http', url.to_scheme
    assert_equal Wgit::Url, url.to_scheme.class
    assert_nil Wgit::Url.new(@link).to_scheme

    url = Wgit::Url.new @iri
    assert_equal 'https', url.to_scheme
    assert_equal Wgit::Url, url.to_scheme.class
    assert_nil Wgit::Url.new('über').to_scheme
  end

  def test_to_host
    assert_equal 'www.google.co.uk', Wgit::Url.new(@url_str_link).to_host
    assert_equal Wgit::Url, Wgit::Url.new(@url_str_link).to_host.class
    assert_nil Wgit::Url.new(@link).to_host

    assert_equal 'www.über.com', Wgit::Url.new(@iri).to_host
    assert_equal Wgit::Url, Wgit::Url.new(@iri).to_host.class
    assert_nil Wgit::Url.new('über').to_host
  end

  def test_to_domain
    assert_equal 'google.co.uk', Wgit::Url.new(@url_str_link).to_domain
    assert_equal Wgit::Url, Wgit::Url.new(@url_str_link).to_domain.class
    assert_nil Wgit::Url.new(@link).to_domain

    assert_equal 'über.com', Wgit::Url.new(@iri).to_domain
    assert_equal Wgit::Url, Wgit::Url.new(@iri).to_domain.class
    assert_nil Wgit::Url.new('über').to_domain

    assert_nil Wgit::Url.new('google.co.uk').to_domain
    assert_nil Wgit::Url.new('/about').to_domain
    assert_nil Wgit::Url.new('?q=hello').to_domain
    assert_nil Wgit::Url.new('#top').to_domain
  end

  def test_to_brand
    assert_equal 'google', Wgit::Url.new(@url_str_link).to_brand
    assert_equal Wgit::Url, Wgit::Url.new(@url_str_link).to_brand.class
    assert_nil Wgit::Url.new(@link).to_brand

    assert_equal 'über', Wgit::Url.new(@iri).to_brand
    assert_equal Wgit::Url, Wgit::Url.new(@iri).to_brand.class

    assert_nil Wgit::Url.new('über').to_brand
    assert_nil Wgit::Url.new('/').to_brand
    assert_nil Wgit::Url.new('').to_brand
    assert_nil Wgit::Url.new('/about').to_brand
    assert_nil Wgit::Url.new('?q=hello').to_brand
    assert_nil Wgit::Url.new('#top').to_brand
  end

  def test_to_base
    assert_equal @url_str, Wgit::Url.new(@url_str_link).to_base
    assert_equal Wgit::Url, Wgit::Url.new(@url_str_link).to_base.class
    assert_nil Wgit::Url.new(@link).to_base

    assert_equal 'https://www.über.com', Wgit::Url.new(@iri).to_base
    assert_equal Wgit::Url, Wgit::Url.new(@iri).to_base.class
    assert_nil Wgit::Url.new('über').to_base

    assert_equal 'https://www.über.com', 'https://www.über.com'.to_url.to_base
    assert_equal Wgit::Url, 'https://www.über.com'.to_url.to_base.class
  end

  def test_to_path
    url = Wgit::Url.new @url_str_link
    assert_equal 'about.html', url.to_path
    assert_equal Wgit::Url, url.to_path.class

    url = Wgit::Url.new '/about.html'
    assert_equal 'about.html', url.to_path
    assert_equal Wgit::Url, url.to_path.class

    url = Wgit::Url.new '/about.html/'
    assert_equal 'about.html', url.to_path
    assert_equal Wgit::Url, url.to_path.class

    url = Wgit::Url.new '/'
    assert_equal '/', url.to_path
    assert_equal Wgit::Url, url.to_path.class

    url = Wgit::Url.new 'about.html'
    assert_equal 'about.html', url.to_path
    assert_equal Wgit::Url, url.to_path.class

    url = Wgit::Url.new @url_str
    assert_nil url.to_path

    url = Wgit::Url.new @url_str_anchor
    assert_equal 'about.html', url.to_path
    assert_equal Wgit::Url, url.to_path.class

    url = Wgit::Url.new @url_str_query
    assert_equal 'about.html', url.to_path
    assert_equal Wgit::Url, url.to_path.class

    url = Wgit::Url.new @iri
    assert_equal 'about', url.to_path
    assert_equal Wgit::Url, url.to_path.class
  end

  def test_to_endpoint
    url = Wgit::Url.new @url_str_link
    assert_equal '/about.html', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new '/about.html'
    assert_equal '/about.html', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new @url_str_link + '/'
    assert_equal '/about.html/', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new '/'
    assert_equal '/', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new 'about.html'
    assert_equal '/about.html', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new @url_str
    assert_equal '/', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new @url_str_anchor
    assert_equal '/about.html', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new @url_str_query
    assert_equal '/about.html', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new @iri
    assert_equal '/about', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class
  end

  def test_to_query_string
    url = Wgit::Url.new @url_str_link + '?q=ruby&page=2'
    assert_equal '?q=ruby&page=2', url.to_query_string
    assert_equal Wgit::Url, url.to_query_string.class

    url = Wgit::Url.new 'https://www.über.com/about?q=ruby&page=2'
    assert_equal '?q=ruby&page=2', url.to_query_string
    assert_equal Wgit::Url, url.to_query_string.class

    url = Wgit::Url.new @url_str
    assert_nil url.to_query_string
  end

  def test_to_anchor
    url = Wgit::Url.new @url_str_anchor
    assert_equal '#about-us', url.to_anchor
    assert_equal Wgit::Url, url.to_anchor.class

    url = Wgit::Url.new '#about-us'
    assert_equal '#about-us', url.to_anchor
    assert_equal Wgit::Url, url.to_anchor.class

    url = Wgit::Url.new @iri
    assert_equal '#top', url.to_anchor
    assert_equal Wgit::Url, url.to_anchor.class

    url = Wgit::Url.new @url_str
    assert_nil url.to_anchor
  end

  def test_to_extension
    url = Wgit::Url.new @url_str_link
    assert_equal 'html', url.to_extension
    assert_equal Wgit::Url, url.to_extension.class

    url = Wgit::Url.new '/img/icon/apple-touch-icon-76x76.png?v=kPgE9zo'
    assert_equal 'png', url.to_extension
    assert_equal Wgit::Url, url.to_extension.class

    url = Wgit::Url.new 'https://www.über.com/about.html'
    assert_equal 'html', url.to_extension
    assert_equal Wgit::Url, url.to_extension.class

    url = Wgit::Url.new @url_str
    assert_nil url.to_extension
  end

  def test_without_leading_slash
    url = Wgit::Url.new @url_str
    assert_equal @url_str, url.without_leading_slash
    assert_equal Wgit::Url, url.without_leading_slash.class

    url = Wgit::Url.new @link
    assert_equal 'about.html', url.without_leading_slash
    assert_equal Wgit::Url, url.without_leading_slash.class

    url = Wgit::Url.new '/über'
    assert_equal 'über', url.without_leading_slash
    assert_equal Wgit::Url, url.without_leading_slash.class
  end

  def test_without_trailing_slash
    url = Wgit::Url.new @url_str
    assert_equal @url_str, url.without_trailing_slash
    assert_equal Wgit::Url, url.without_trailing_slash.class

    url = Wgit::Url.new @url_str + '/'
    assert_equal @url_str, url.without_trailing_slash
    assert_equal Wgit::Url, url.without_trailing_slash.class

    url = Wgit::Url.new 'über/'
    assert_equal 'über', url.without_trailing_slash
    assert_equal Wgit::Url, url.without_trailing_slash.class
  end

  def test_without_slashes
    url = Wgit::Url.new 'link.html'
    assert_equal 'link.html', url.without_slashes
    assert_equal Wgit::Url, url.without_slashes.class

    url = Wgit::Url.new '/link.html/'
    assert_equal 'link.html', url.without_slashes
    assert_equal Wgit::Url, url.without_slashes.class

    url = Wgit::Url.new '/über/'
    assert_equal 'über', url.without_slashes
    assert_equal Wgit::Url, url.without_slashes.class
  end

  def test_without_base
    url = Wgit::Url.new 'http://google.com/search?q=foo#bar'
    assert_equal 'search?q=foo#bar', url.without_base
    assert_equal Wgit::Url, url.without_base.class

    url = Wgit::Url.new '/about.html'
    assert_equal 'about.html', url.without_base
    assert_equal Wgit::Url, url.without_base.class

    url = Wgit::Url.new '/about.html#hello/'
    assert_equal 'about.html#hello', url.without_base
    assert_equal Wgit::Url, url.without_base.class

    url = Wgit::Url.new '/about.html/hello?a=b&b=c#about'
    assert_equal 'about.html/hello?a=b&b=c#about', url.without_base
    assert_equal Wgit::Url, url.without_base.class

    url = Wgit::Url.new '/'
    assert_equal url, url.without_base
    assert_equal Wgit::Url, url.without_base.class

    url = Wgit::Url.new 'https://google.com/'
    assert_equal url, url.without_base
    assert_equal Wgit::Url, url.without_base.class

    url = Wgit::Url.new 'https://google.com'
    assert_equal url, url.without_base
    assert_equal Wgit::Url, url.without_base.class

    url = Wgit::Url.new @iri
    assert_equal 'about#top', url.without_base
    assert_equal Wgit::Url, url.without_base.class
  end

  def test_without_query_string
    url = Wgit::Url.new 'http://google.com/search?q=hello&foo=bar'
    assert_equal 'http://google.com/search', url.without_query_string
    assert_equal Wgit::Url, url.without_query_string.class

    url = Wgit::Url.new '/about.html'
    assert_equal '/about.html', url.without_query_string
    assert_equal Wgit::Url, url.without_query_string.class

    url = Wgit::Url.new '/about.html?q=hello&foo=bar'
    assert_equal '/about.html', url.without_query_string
    assert_equal Wgit::Url, url.without_query_string.class

    url = Wgit::Url.new '/about.html/hello?a=b&b=c#about'
    assert_equal '/about.html/hello#about', url.without_query_string
    assert_equal Wgit::Url, url.without_query_string.class

    url = Wgit::Url.new '/about.html/hello#about?a=b&b=c' # Invalid anchor.
    assert_equal '/about.html/hello#about?a=b&b=c', url.without_query_string
    assert_equal Wgit::Url, url.without_query_string.class

    url = Wgit::Url.new '/'
    assert_equal url, url.without_query_string
    assert_equal Wgit::Url, url.without_query_string.class

    url = Wgit::Url.new '?q=hello&foo=bar'
    assert_empty url.without_query_string
    assert_equal Wgit::Url, url.without_query_string.class

    url = Wgit::Url.new 'https://google.com/'
    assert_equal url, url.without_query_string
    assert_equal Wgit::Url, url.without_query_string.class

    url = Wgit::Url.new 'https://google.com'
    assert_equal url, url.without_query_string
    assert_equal Wgit::Url, url.without_query_string.class

    iri_without_anchor = 'https://www.über.com/about'
    url = Wgit::Url.new iri_without_anchor + '?q=hello'
    assert_equal iri_without_anchor, url.without_query_string
    assert_equal Wgit::Url, url.without_query_string.class
  end

  def test_without_anchor
    url = Wgit::Url.new 'http://google.com/search?q=foo#bar'
    assert_equal 'http://google.com/search?q=foo', url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class

    url = Wgit::Url.new '/about.html'
    assert_equal '/about.html', url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class

    url = Wgit::Url.new '/about.html#hello/'
    assert_equal '/about.html', url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class

    url = Wgit::Url.new '/about.html/hello?a=b&b=c#about'
    assert_equal '/about.html/hello?a=b&b=c', url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class

    url = Wgit::Url.new '/about.html/hello#about?a=b&b=c' # Invalid anchor.
    assert_equal '/about.html/hello', url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class

    url = Wgit::Url.new '/'
    assert_equal url, url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class

    url = Wgit::Url.new '#about'
    assert_empty url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class

    url = Wgit::Url.new '/about#'
    assert_equal '/about', url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class

    url = Wgit::Url.new 'https://google.com/'
    assert_equal url, url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class

    url = Wgit::Url.new 'https://google.com'
    assert_equal url, url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class

    url = Wgit::Url.new @iri
    assert_equal 'https://www.über.com/about', url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class
  end

  def test_is_query_string?
    url = Wgit::Url.new '?q=hello'
    assert url.is_query_string?

    url = Wgit::Url.new '?q=hello&z=world'
    assert url.is_query_string?

    url = Wgit::Url.new '#top'
    refute url.is_query_string?

    url = Wgit::Url.new '/about?q=hello'
    refute url.is_query_string?

    url = Wgit::Url.new 'http://example.com?q=hello'
    refute url.is_query_string?
  end

  def test_is_anchor?
    url = Wgit::Url.new '#'
    assert url.is_anchor?

    url = Wgit::Url.new '?q=hello'
    refute url.is_anchor?

    url = Wgit::Url.new '/public#top'
    refute url.is_anchor?

    url = Wgit::Url.new 'http://example.com#top'
    refute url.is_anchor?

    url = Wgit::Url.new 'http://example.com/home#top'
    refute url.is_anchor?
  end

  def test_to_h
    assert_equal @mongo_doc_dup, Wgit::Url.new(@mongo_doc_dup).to_h
  end
end
