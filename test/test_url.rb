# frozen_string_literal: true

require_relative 'helpers/test_helper'

# Test class for Url methods.
class TestUrl < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_initialize__from_string
    url = Wgit::Url.new 'http://www.google.co.uk'

    assert_equal 'http://www.google.co.uk', url
    refute url.crawled
    assert_nil url.date_crawled

    url = Wgit::Url.new 'http://www.google.co.uk', crawled: true, date_crawled: @time_stamp

    assert_equal 'http://www.google.co.uk', url
    assert url.crawled
    assert_equal @time_stamp, url.date_crawled
  end

  def test_initialize__from_url
    temp_url = Wgit::Url.new 'http://www.google.co.uk'
    url = Wgit::Url.new temp_url

    assert_equal 'http://www.google.co.uk', url
    refute url.crawled
    assert_nil url.date_crawled
  end

  def test_initialize__from_iri
    url = Wgit::Url.new 'https://www.über.com/about#top'

    assert_equal 'https://www.über.com/about#top', url
    refute url.crawled
    assert_nil url.date_crawled
  end

  def test_initialize__from_mongo_doc
    time = Time.now
    url = Wgit::Url.new(
      'url' => 'http://www.google.co.uk',
      'crawled' => true,
      'date_crawled' => time
    )

    assert_equal 'http://www.google.co.uk', url
    assert url.crawled
    assert_equal time, url.date_crawled
  end

  def test_parse__from_string
    url = Wgit::Url.parse 'http://www.google.co.uk'

    assert_equal 'http://www.google.co.uk', url
    refute url.crawled
    assert_nil url.date_crawled
    refute_nil url.instance_variable_get :@uri
  end

  def test_parse__from_url
    url = Wgit::Url.new 'http://example.com', crawled: true, date_crawled: Time.now
    parsed = Wgit::Url.parse url

    assert_equal 'http://example.com', parsed
    assert url.crawled
    refute_nil url.date_crawled
    refute_nil url.instance_variable_get :@uri
  end

  def test_parse__fails
    e = assert_raises { Wgit::Url.parse nil }
    assert_equal 'Can only parse if obj#is_a?(String)', e.message

    e = assert_raises { Wgit::Url.parse({}) }
    assert_equal 'Can only parse if obj#is_a?(String)', e.message
  end

  def test_valid?
    assert Wgit::Url.new('http://www.google.co.uk').valid?
    refute Wgit::Url.new('my_server').valid?
    assert Wgit::Url.new('http://www.google.co.uk/about.html#about-us').valid?
    assert Wgit::Url.new('https://www.über.com/about#top').valid?
    refute Wgit::Url.new('/über').valid?
  end

  def test_prefix_protocol
    assert_equal 'http://my_server', Wgit::Url.new('my_server').prefix_protocol
    assert_equal 'https://my_server', Wgit::Url.new('my_server').prefix_protocol(protocol: :https)
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

  def test_relative?
    # Common type URL's.
    assert Wgit::Url.new('/about.html').relative?
    refute Wgit::Url.new('http://www.google.co.uk').relative?

    # IRI's.
    assert Wgit::Url.new('/über').relative?
    refute Wgit::Url.new('https://www.über.com/about#top').relative?

    # Single slash URL's.
    assert Wgit::Url.new('/').relative?

    # Anchors/fragments.
    assert Wgit::Url.new('#about-us').relative?
    refute Wgit::Url.new('http://www.google.co.uk/about.html#about-us').relative?

    # Query string params.
    assert Wgit::Url.new('?foo=bar').relative?
    refute Wgit::Url.new('http://www.google.co.uk/about.html?foo=bar').relative?

    # Valid error scenarios.
    e = assert_raises(StandardError) { Wgit::Url.new('').relative? }
    assert_equal 'Url (self) cannot be empty', e.message

    e = assert_raises(StandardError) do
      Wgit::Url.new('http://example.com').relative?(host: '1', brand: '2')
    end
    assert_equal 'Provide only one of: [:base, :host, :domain, :brand]', e.message

    e = assert_raises(StandardError) do
      Wgit::Url.new('http://example.com').relative?(foo: 'http://example.com')
    end
    assert_equal 'Unknown opts param: :foo, use one of: [:base, :host, :domain, :brand]', e.message

    e = assert_raises(StandardError) do
      Wgit::Url.new('http://example.com').relative?(foo: '/')
    end
    assert_equal 'Invalid opts param value, Url must be absolute and contain protocol: /', e.message
  end

  def test_relative__with_base
    # IRI's.
    assert Wgit::Url.new('https://www.über.com/about#top').relative? base: 'https://www.über.com'
    refute Wgit::Url.new('https://www.über.com/about#top').relative? base: 'https://www.überon.com'

    # URL's with paths (including slashes).
    assert Wgit::Url.new('http://www.google.co.uk/about.html').relative? base: 'http://www.google.co.uk'
    refute Wgit::Url.new('https://www.google.co.uk').relative? base: 'http://www.google.co.uk' # Diff protocol.
    refute Wgit::Url.new('http://www.google.co.uk/about.html').relative? base: 'http://bing.com'
    assert Wgit::Url.new('http://www.google.co.uk').relative? base: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/').relative? base: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/').relative? base: 'http://www.google.co.uk/'

    # Single slash URL's.
    assert Wgit::Url.new('/').relative? base: 'http://www.google.co.uk'

    # Anchors/fragments.
    assert Wgit::Url.new('#about-us').relative? base: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/about.html#about-us').relative? base: 'http://www.google.co.uk'

    # Query string params.
    assert Wgit::Url.new('?foo=bar').relative? base: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/about.html?foo=bar').relative? base: 'http://www.google.co.uk'

    # URL specific.
    refute(
      Wgit::Url.new('http://www.example.com/search').relative?(base: 'https://ftp.example.com')
    )
    refute(
      'http://www.example.com/search'.to_url.relative?(base: 'https://ftp.example.com'.to_url)
    )
    refute(
      'http://www.example.com/search'.to_url.relative?(base: 'https://ftp.example.co.uk'.to_url)
    )
    refute(
      'https://server.example.com'.to_url.relative?(base: 'https://example.com/en'.to_url)
    )

    # Valid error scenarios.
    e = assert_raises(StandardError) do
      Wgit::Url.new('http://www.google.co.uk/about.html').relative? base: 'bing.com'
    end
    assert_equal(
      'Invalid opts param value, Url must be absolute and contain protocol: bing.com',
      e.message
    )
  end

  def test_relative__with_host
    # IRI's.
    assert Wgit::Url.new('https://www.über.com/about#top').relative? host: 'https://www.über.com'
    refute Wgit::Url.new('https://www.über.com/about#top').relative? host: 'https://www.überon.com'

    # URL's with paths (including slashes).
    assert Wgit::Url.new('http://www.google.co.uk/about.html').relative? host: 'http://www.google.co.uk'
    assert Wgit::Url.new('https://www.google.co.uk').relative? host: 'http://www.google.co.uk' # Diff protocol.
    refute Wgit::Url.new('http://www.google.co.uk/about.html').relative? host: 'http://bing.com'
    assert Wgit::Url.new('http://www.google.co.uk').relative? host: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/').relative? host: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/').relative? host: 'http://www.google.co.uk/'

    # Single slash URL's.
    assert Wgit::Url.new('/').relative? host: 'http://www.google.co.uk'

    # Anchors/fragments.
    assert Wgit::Url.new('#about-us').relative? host: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/about.html#about-us').relative? host: 'http://www.google.co.uk'

    # Query string params.
    assert Wgit::Url.new('?foo=bar').relative? host: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/about.html?foo=bar').relative? host: 'http://www.google.co.uk'

    # URL specific.
    refute(
      Wgit::Url.new('http://www.example.com/search').relative?(host: 'https://ftp.example.com')
    )
    refute(
      'http://www.example.com/search'.to_url.relative?(host: 'https://ftp.example.com'.to_url)
    )
    refute(
      'http://www.example.com/search'.to_url.relative?(host: 'https://ftp.example.co.uk'.to_url)
    )
    refute(
      'https://server.example.com'.to_url.relative?(host: 'https://example.com/en'.to_url)
    )

    # Valid error scenarios.
    e = assert_raises(StandardError) do
      Wgit::Url.new('http://www.google.co.uk/about.html').relative? host: 'bing.com'
    end
    assert_equal(
      'Invalid opts param value, Url must be absolute and contain protocol: bing.com',
      e.message
    )
  end

  def test_relative__with_domain
    # IRI's.
    assert Wgit::Url.new('https://www.über.com/about#top').relative? domain: 'https://www.über.com'
    refute Wgit::Url.new('https://www.über.com/about#top').relative? domain: 'https://www.überon.com'

    # URL's with paths (including slashes).
    assert Wgit::Url.new('http://www.google.co.uk/about.html').relative? domain: 'http://www.google.co.uk'
    assert Wgit::Url.new('https://www.google.co.uk').relative? domain: 'http://www.google.co.uk' # Diff protocol.
    refute Wgit::Url.new('http://www.google.co.uk/about.html').relative? domain: 'http://bing.com'
    assert Wgit::Url.new('http://www.google.co.uk').relative? domain: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/').relative? domain: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/').relative? domain: 'http://www.google.co.uk/'

    # Single slash URL's.
    assert Wgit::Url.new('/').relative? domain: 'http://www.google.co.uk'

    # Anchors/fragments.
    assert Wgit::Url.new('#about-us').relative? domain: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/about.html#about-us').relative? domain: 'http://www.google.co.uk'

    # Query string params.
    assert Wgit::Url.new('?foo=bar').relative? domain: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/about.html?foo=bar').relative? domain: 'http://www.google.co.uk'

    # URL specific.
    assert(
      Wgit::Url.new('http://www.example.com/search').relative?(domain: 'https://ftp.example.com')
    )
    assert(
      'http://www.example.com/search'.to_url.relative?(domain: 'https://ftp.example.com'.to_url)
    )
    refute(
      'http://www.example.com/search'.to_url.relative?(domain: 'https://ftp.example.co.uk'.to_url)
    )
    assert(
      'https://server.example.com'.to_url.relative?(domain: 'https://example.com/en'.to_url)
    )

    # Valid error scenarios.
    e = assert_raises(StandardError) do
      Wgit::Url.new('http://www.google.co.uk/about.html').relative? domain: 'bing.com'
    end
    assert_equal(
      'Invalid opts param value, Url must be absolute and contain protocol: bing.com',
      e.message
    )
  end

  def test_relative__with_brand
    # IRI's.
    assert Wgit::Url.new('https://www.über.com/about#top').relative? brand: 'https://www.über.com'
    assert Wgit::Url.new('https://www.über.com/about#top').relative? brand: 'https://www.über.co.uk'

    # URL's with paths (including slashes).
    assert Wgit::Url.new('http://www.google.co.uk/about.html').relative? brand: 'http://www.google.co.uk'
    assert Wgit::Url.new('https://www.google.co.uk').relative? brand: 'http://www.google.co.uk' # Diff protocol.
    assert Wgit::Url.new('http://www.google.co.uk/about.html').relative? brand: 'https://www.google.com'
    refute Wgit::Url.new('http://www.google.co.uk/about.html').relative? brand: 'http://bing.com'
    assert Wgit::Url.new('http://www.google.co.uk').relative? brand: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/').relative? brand: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/').relative? brand: 'http://www.google.co.uk/'

    # Single slash URL's.
    assert Wgit::Url.new('/').relative? brand: 'http://www.google.co.uk'

    # Anchors/fragments.
    assert Wgit::Url.new('#about-us').relative? brand: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/about.html#about-us').relative? brand: 'http://www.google.co.uk'

    # Query string params.
    assert Wgit::Url.new('?foo=bar').relative? brand: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/about.html?foo=bar').relative? brand: 'http://www.google.co.uk'

    # URL specific.
    assert(
      Wgit::Url.new('http://www.example.com/search').relative?(brand: 'https://ftp.example.com')
    )
    assert(
      Wgit::Url.new('http://www.example.co.uk/search').relative?(brand: 'https://ftp.example.com')
    )
    assert(
      'http://www.example.com/search'.to_url.relative?(brand: 'https://ftp.example.com'.to_url)
    )
    assert(
      'http://www.example.com/search'.to_url.relative?(brand: 'https://ftp.example.co.uk'.to_url)
    )
    refute(
      'https://server.example.com'.to_url.relative?(brand: 'https://example2.com/en'.to_url)
    )

    # Valid error scenarios.
    e = assert_raises(StandardError) do
      Wgit::Url.new('http://www.google.co.uk/about.html').relative? brand: 'bing.com'
    end
    assert_equal(
      'Invalid opts param value, Url must be absolute and contain protocol: bing.com',
      e.message
    )
  end

  def test_absolute?
    assert Wgit::Url.new('http://www.google.co.uk').absolute?
    refute Wgit::Url.new('/about.html').absolute?
  end

  def test_concat
    assert_equal 'http://www.google.co.uk/about.html', Wgit::Url.new('http://www.google.co.uk').concat('/about.html')
    assert_equal 'http://www.google.co.uk/about.html', Wgit::Url.new('http://www.google.co.uk').concat('about.html')
    assert_equal 'http://www.google.co.uk/about.html#about-us', Wgit::Url.new('http://www.google.co.uk/about.html').concat('#about-us')
    assert_equal 'http://www.google.co.uk/about.html?foo=bar', Wgit::Url.new('http://www.google.co.uk/about.html').concat('?foo=bar')
    assert_equal 'http://example.com/', Wgit::Url.new('http://example.com').concat('/')
    assert_equal 'http://example.com/', Wgit::Url.new('http://example.com/').concat('/')
    assert_equal 'http://google.com/about/help', Wgit::Url.new('http://google.com/about').concat('help')
    assert_equal 'https://www.über?foo=bar', Wgit::Url.new('https://www.über').concat('?foo=bar')

    e = assert_raises(StandardError) do
      Wgit::Url.new('https://www.über').concat('https://example.com')
    end
    assert_equal 'path must be relative', e.message
  end

  def test_crawled=
    url = Wgit::Url.new 'http://www.google.co.uk'
    url.crawled = true
    assert url.crawled
    assert url.crawled?
  end

  def test_normalise
    # Normalise an IRI.
    url = Wgit::Url.new 'https://www.über.com/about#top'
    normalised = url.normalize

    assert_instance_of Wgit::Url, normalised
    assert_equal 'https://www.xn--ber-goa.com/about#top', normalised

    # Already normalised URL's stay the same.
    url = Wgit::Url.new 'https://www.example.com/blah#top'
    normalised = url.normalize

    assert_instance_of Wgit::Url, normalised
    assert_equal 'https://www.example.com/blah#top', normalised
  end

  def test_to_uri
    assert_equal URI::HTTP, Wgit::Url.new('http://www.google.co.uk').to_uri.class
    assert_equal URI::HTTPS, Wgit::Url.new('https://blah.com').to_uri.class

    uri = Wgit::Url.new('https://www.über.com/about#top').to_uri
    assert_equal URI::HTTPS, uri.class
    assert_equal 'https://www.xn--ber-goa.com/about#top', uri.to_s
  end

  def test_to_url
    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_equal url.object_id, url.to_url.object_id
    assert_equal url, url.to_url
    assert_equal Wgit::Url, url.to_url.class

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal url.object_id, url.to_url.object_id
    assert_equal url, url.to_url
    assert_equal Wgit::Url, url.to_url.class
  end

  def test_to_scheme
    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_equal 'http', url.to_scheme
    assert_equal Wgit::Url, url.to_scheme.class
    assert_nil Wgit::Url.new('/about.html').to_scheme

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal 'https', url.to_scheme
    assert_equal Wgit::Url, url.to_scheme.class
    assert_nil Wgit::Url.new('über').to_scheme
  end

  def test_to_host
    assert_equal 'www.google.co.uk', Wgit::Url.new('http://www.google.co.uk/about.html').to_host
    assert_equal Wgit::Url, Wgit::Url.new('http://www.google.co.uk/about.html').to_host.class
    assert_nil Wgit::Url.new('/about.html').to_host

    assert_equal 'www.über.com', Wgit::Url.new('https://www.über.com/about#top').to_host
    assert_equal Wgit::Url, Wgit::Url.new('https://www.über.com/about#top').to_host.class
    assert_nil Wgit::Url.new('über').to_host
  end

  def test_to_domain
    assert_equal 'google.co.uk', Wgit::Url.new('http://www.google.co.uk/about.html').to_domain
    assert_equal Wgit::Url, Wgit::Url.new('http://www.google.co.uk/about.html').to_domain.class
    assert_nil Wgit::Url.new('/about.html').to_domain

    assert_equal 'über.com', Wgit::Url.new('https://www.über.com/about#top').to_domain
    assert_equal Wgit::Url, Wgit::Url.new('https://www.über.com/about#top').to_domain.class
    assert_nil Wgit::Url.new('über').to_domain

    assert_nil Wgit::Url.new('google.co.uk').to_domain
    assert_nil Wgit::Url.new('/about').to_domain
    assert_nil Wgit::Url.new('?q=hello').to_domain
    assert_nil Wgit::Url.new('#top').to_domain
  end

  def test_to_brand
    assert_equal 'google', Wgit::Url.new('http://www.google.co.uk/about.html').to_brand
    assert_equal Wgit::Url, Wgit::Url.new('http://www.google.co.uk/about.html').to_brand.class
    assert_nil Wgit::Url.new('/about.html').to_brand

    assert_equal 'über', Wgit::Url.new('https://www.über.com/about#top').to_brand
    assert_equal Wgit::Url, Wgit::Url.new('https://www.über.com/about#top').to_brand.class

    assert_nil Wgit::Url.new('über').to_brand
    assert_nil Wgit::Url.new('/').to_brand
    assert_nil Wgit::Url.new('').to_brand
    assert_nil Wgit::Url.new('/about').to_brand
    assert_nil Wgit::Url.new('?q=hello').to_brand
    assert_nil Wgit::Url.new('#top').to_brand
  end

  def test_to_base
    assert_equal 'http://www.google.co.uk', Wgit::Url.new('http://www.google.co.uk/about.html').to_base
    assert_equal Wgit::Url, Wgit::Url.new('http://www.google.co.uk/about.html').to_base.class
    assert_nil Wgit::Url.new('/about.html').to_base

    assert_equal 'https://www.über.com', Wgit::Url.new('https://www.über.com/about#top').to_base
    assert_equal Wgit::Url, Wgit::Url.new('https://www.über.com/about#top').to_base.class
    assert_nil Wgit::Url.new('über').to_base

    assert_equal 'https://www.über.com', 'https://www.über.com'.to_url.to_base
    assert_equal Wgit::Url, 'https://www.über.com'.to_url.to_base.class
  end

  def test_to_path
    url = Wgit::Url.new 'http://www.google.co.uk/about.html'
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

    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_nil url.to_path

    url = Wgit::Url.new 'http://www.google.co.uk/about.html#about-us'
    assert_equal 'about.html', url.to_path
    assert_equal Wgit::Url, url.to_path.class

    url = Wgit::Url.new 'http://www.google.co.uk/about.html?foo=bar'
    assert_equal 'about.html', url.to_path
    assert_equal Wgit::Url, url.to_path.class

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal 'about', url.to_path
    assert_equal Wgit::Url, url.to_path.class
  end

  def test_to_endpoint
    url = Wgit::Url.new 'http://www.google.co.uk/about.html'
    assert_equal '/about.html', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new '/about.html'
    assert_equal '/about.html', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new 'http://www.google.co.uk/about.html/'
    assert_equal '/about.html/', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new '/'
    assert_equal '/', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new 'about.html'
    assert_equal '/about.html', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_equal '/', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new 'http://www.google.co.uk/about.html#about-us'
    assert_equal '/about.html', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new 'http://www.google.co.uk/about.html?foo=bar'
    assert_equal '/about.html', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal '/about', url.to_endpoint
    assert_equal Wgit::Url, url.to_endpoint.class
  end

  def test_to_query_string
    url = Wgit::Url.new 'http://www.google.co.uk/about.html?q=ruby&page=2'
    assert_equal '?q=ruby&page=2', url.to_query
    assert_equal Wgit::Url, url.to_query.class

    url = Wgit::Url.new 'https://www.über.com/about?q=ruby&page=2'
    assert_equal '?q=ruby&page=2', url.to_query
    assert_equal Wgit::Url, url.to_query.class

    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_nil url.to_query
  end

  def test_to_anchor
    url = Wgit::Url.new 'http://www.google.co.uk/about.html#about-us'
    assert_equal '#about-us', url.to_anchor
    assert_equal Wgit::Url, url.to_anchor.class

    url = Wgit::Url.new '#about-us'
    assert_equal '#about-us', url.to_anchor
    assert_equal Wgit::Url, url.to_anchor.class

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal '#top', url.to_anchor
    assert_equal Wgit::Url, url.to_anchor.class

    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_nil url.to_anchor
  end

  def test_to_extension
    url = Wgit::Url.new 'http://www.google.co.uk/about.html'
    assert_equal 'html', url.to_extension
    assert_equal Wgit::Url, url.to_extension.class

    url = Wgit::Url.new '/img/icon/apple-touch-icon-76x76.png?v=kPgE9zo'
    assert_equal 'png', url.to_extension
    assert_equal Wgit::Url, url.to_extension.class

    url = Wgit::Url.new 'https://www.über.com/about.html'
    assert_equal 'html', url.to_extension
    assert_equal Wgit::Url, url.to_extension.class

    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_nil url.to_extension
  end

  def test_without_leading_slash
    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_equal 'http://www.google.co.uk', url.without_leading_slash
    assert_equal Wgit::Url, url.without_leading_slash.class

    url = Wgit::Url.new '/about.html'
    assert_equal 'about.html', url.without_leading_slash
    assert_equal Wgit::Url, url.without_leading_slash.class

    url = Wgit::Url.new '/über'
    assert_equal 'über', url.without_leading_slash
    assert_equal Wgit::Url, url.without_leading_slash.class
  end

  def test_without_trailing_slash
    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_equal 'http://www.google.co.uk', url.without_trailing_slash
    assert_equal Wgit::Url, url.without_trailing_slash.class

    url = Wgit::Url.new 'http://www.google.co.uk/'
    assert_equal 'http://www.google.co.uk', url.without_trailing_slash
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

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal 'about#top', url.without_base
    assert_equal Wgit::Url, url.without_base.class
  end

  def test_without_query_string
    url = Wgit::Url.new 'http://google.com/search?q=hello&foo=bar'
    assert_equal 'http://google.com/search', url.without_query
    assert_equal Wgit::Url, url.without_query.class

    url = Wgit::Url.new '/about.html'
    assert_equal '/about.html', url.without_query
    assert_equal Wgit::Url, url.without_query.class

    url = Wgit::Url.new '/about.html?q=hello&foo=bar'
    assert_equal '/about.html', url.without_query
    assert_equal Wgit::Url, url.without_query.class

    url = Wgit::Url.new '/about.html/hello?a=b&b=c#about'
    assert_equal '/about.html/hello#about', url.without_query
    assert_equal Wgit::Url, url.without_query.class

    url = Wgit::Url.new '/about.html/hello#about?a=b&b=c' # Invalid anchor.
    assert_equal '/about.html/hello#about?a=b&b=c', url.without_query
    assert_equal Wgit::Url, url.without_query.class

    url = Wgit::Url.new '/'
    assert_equal url, url.without_query
    assert_equal Wgit::Url, url.without_query.class

    url = Wgit::Url.new '?q=hello&foo=bar'
    assert_empty url.without_query
    assert_equal Wgit::Url, url.without_query.class

    url = Wgit::Url.new 'https://google.com/'
    assert_equal url, url.without_query
    assert_equal Wgit::Url, url.without_query.class

    url = Wgit::Url.new 'https://google.com'
    assert_equal url, url.without_query
    assert_equal Wgit::Url, url.without_query.class

    iri_without_anchor = 'https://www.über.com/about'
    url = Wgit::Url.new iri_without_anchor + '?q=hello'
    assert_equal iri_without_anchor, url.without_query
    assert_equal Wgit::Url, url.without_query.class
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

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal 'https://www.über.com/about', url.without_anchor
    assert_equal Wgit::Url, url.without_anchor.class
  end

  def test_query?
    url = Wgit::Url.new '?q=hello'
    assert url.query?

    url = Wgit::Url.new '?q=hello&z=world'
    assert url.query?

    url = Wgit::Url.new '#top'
    refute url.query?

    url = Wgit::Url.new '/about?q=hello'
    refute url.query?

    url = Wgit::Url.new 'http://example.com?q=hello'
    refute url.query?
  end

  def test_anchor?
    url = Wgit::Url.new '#'
    assert url.anchor?

    url = Wgit::Url.new '?q=hello'
    refute url.anchor?

    url = Wgit::Url.new '/public#top'
    refute url.anchor?

    url = Wgit::Url.new 'http://example.com#top'
    refute url.anchor?

    url = Wgit::Url.new 'http://example.com/home#top'
    refute url.anchor?
  end

  def test_to_h
    mongo_doc = {
      'url' => 'http://www.google.co.uk',
      'crawled' => true,
      'date_crawled' => Time.now
    }
    assert_equal mongo_doc, Wgit::Url.new(mongo_doc).to_h
  end
end
