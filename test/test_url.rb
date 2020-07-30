# frozen_string_literal: true

require_relative 'helpers/test_helper'

# Test class for Url methods.
class TestUrl < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_initialize__from_string
    time = Time.now
    url = Wgit::Url.new 'http://www.google.co.uk'

    assert_equal 'http://www.google.co.uk', url
    refute url.crawled
    assert_nil url.date_crawled
    assert_nil url.crawl_duration
    refute_nil url.instance_variable_get :@uri

    url = Wgit::Url.new(
      'http://www.google.co.uk',
      crawled: true,
      date_crawled: time,
      crawl_duration: 1.5
    )

    assert_equal 'http://www.google.co.uk', url
    assert url.crawled
    assert_equal time, url.date_crawled
    assert_equal 1.5, url.crawl_duration
    refute_nil url.instance_variable_get :@uri
  end

  def test_initialize__from_url
    temp_url = Wgit::Url.new 'http://www.google.co.uk'
    url = Wgit::Url.new temp_url

    assert_equal 'http://www.google.co.uk', url
    refute url.crawled
    assert_nil url.date_crawled
    assert_nil url.crawl_duration
    refute_nil url.instance_variable_get :@uri
  end

  def test_initialize__from_iri
    url = Wgit::Url.new 'https://www.über.com/about#top'

    assert_equal 'https://www.über.com/about#top', url
    refute url.crawled
    assert_nil url.date_crawled
    assert_nil url.crawl_duration
    refute_nil url.instance_variable_get :@uri
  end

  def test_initialize__from_mongo_doc
    time = Time.now
    url = Wgit::Url.new({
      'url' => 'http://www.google.co.uk',
      'crawled' => true,
      'date_crawled' => time,
      'crawl_duration' => 1.5
    })

    assert_equal 'http://www.google.co.uk', url
    assert url.crawled
    assert_equal time, url.date_crawled
    assert_equal 1.5, url.crawl_duration
    refute_nil url.instance_variable_get :@uri
  end

  def test_parse__from_string
    url = Wgit::Url.parse 'http://www.google.co.uk'

    assert_equal 'http://www.google.co.uk', url
    refute url.crawled
    assert_nil url.date_crawled
    assert_nil url.crawl_duration
    refute_nil url.instance_variable_get :@uri
  end

  def test_parse__from_url
    time = Time.now
    url = Wgit::Url.new(
      'http://example.com',
      crawled: true,
      date_crawled: time,
      crawl_duration: 1.5
    )
    parsed = Wgit::Url.parse url

    assert_equal 'http://example.com', parsed
    assert url.crawled
    assert_equal time, url.date_crawled
    assert_equal 1.5, url.crawl_duration
    refute_nil url.instance_variable_get :@uri
  end

  def test_parse__fails
    e = assert_raises { Wgit::Url.parse nil }
    assert_equal 'Can only parse if obj#is_a?(String)', e.message

    e = assert_raises { Wgit::Url.parse({}) }
    assert_equal 'Can only parse if obj#is_a?(String)', e.message
  end

  def test_parse_or_nil__from_string
    url = Wgit::Url.parse? 'http://www.google.co.uk'

    assert_equal 'http://www.google.co.uk', url
    refute url.crawled
    assert_nil url.date_crawled
    assert_nil url.crawl_duration
    refute_nil url.instance_variable_get :@uri
  end

  def test_parse_or_nil__from_url
    time = Time.now
    url = Wgit::Url.new(
      'http://example.com',
      crawled: true,
      date_crawled: time,
      crawl_duration: 1.5
    )
    parsed = Wgit::Url.parse? url

    assert_equal 'http://example.com', parsed
    assert url.crawled
    assert_equal time, url.date_crawled
    assert_equal 1.5, url.crawl_duration
    refute_nil url.instance_variable_get :@uri
  end

  def test_parse_or_nil__returns_nil
    assert_nil Wgit::Url.parse?('http://')
    assert_nil Wgit::Url.parse?('https://')
  end

  def test_parse_or_nil__fails
    e = assert_raises { Wgit::Url.parse? nil }
    assert_equal 'Can only parse if obj#is_a?(String)', e.message

    e = assert_raises { Wgit::Url.parse?({}) }
    assert_equal 'Can only parse if obj#is_a?(String)', e.message
  end

  def test_valid?
    assert Wgit::Url.new('http://www.google.co.uk').valid?
    assert Wgit::Url.new('http://google.com').valid?
    refute Wgit::Url.new('http://google').valid?
    refute Wgit::Url.new('http://google/').valid?
    refute Wgit::Url.new('my_server').valid?
    refute Wgit::Url.new('my_server.com').valid?
    assert Wgit::Url.new('http://www.google.co.uk/about.html#about-us').valid?
    assert Wgit::Url.new('https://www.über.com/about#top').valid?
    refute Wgit::Url.new('/über').valid?
    assert Wgit::Url.new('https://über.com').valid?
  end

  def test_invalid?
    refute Wgit::Url.new('http://www.google.co.uk').invalid?
    refute Wgit::Url.new('http://google.com').invalid?
    assert Wgit::Url.new('http://google').invalid?
    assert Wgit::Url.new('http://google/').invalid?
    assert Wgit::Url.new('my_server').invalid?
    assert Wgit::Url.new('my_server.com').invalid?
    refute Wgit::Url.new('http://www.google.co.uk/about.html#about-us').invalid?
    refute Wgit::Url.new('https://www.über.com/about#top').invalid?
    assert Wgit::Url.new('/über').invalid?
    refute Wgit::Url.new('https://über.com').invalid?
  end

  def test_prefix_base
    doc = Wgit::Document.new 'http://example.com'

    url = Wgit::Url.new 'http://www.google.co.uk/about.html'
    assert_equal 'http://www.google.co.uk/about.html', url.prefix_base(doc)
    assert_equal Wgit::Url, url.prefix_base(doc).class

    url = Wgit::Url.new '/about.html'
    assert_equal 'http://example.com/about.html', url.prefix_base(doc)
    assert_equal Wgit::Url, url.prefix_base(doc).class

    url = Wgit::Url.new '/about.html/'
    assert_equal 'http://example.com/about.html/', url.prefix_base(doc)
    assert_equal Wgit::Url, url.prefix_base(doc).class

    url = Wgit::Url.new '/'
    assert_equal 'http://example.com/', url.prefix_base(doc)
    assert_equal Wgit::Url, url.prefix_base(doc).class

    url = Wgit::Url.new 'about.html'
    assert_equal 'http://example.com/about.html', url.prefix_base(doc)
    assert_equal Wgit::Url, url.prefix_base(doc).class

    url = Wgit::Url.new '#about-us'
    assert_equal 'http://example.com#about-us', url.prefix_base(doc)
    assert_equal Wgit::Url, url.prefix_base(doc).class

    url = Wgit::Url.new '?foo=bar'
    assert_equal 'http://example.com?foo=bar', url.prefix_base(doc)
    assert_equal Wgit::Url, url.prefix_base(doc).class

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal 'https://www.über.com/about#top', url.prefix_base(doc)
    assert_equal Wgit::Url, url.prefix_base(doc).class

    ex = assert_raises(StandardError) { 'blah'.to_url.prefix_base(true) }
    assert_equal 'Expected: Wgit::Document, Actual: TrueClass', ex.message
  end

  def test_prefix_scheme
    assert_equal 'http://my_server', Wgit::Url.new('my_server').prefix_scheme
    assert_equal 'https://my_server', Wgit::Url.new('my_server').prefix_scheme(protocol: :https)
    assert_equal 'http://my_server', Wgit::Url.new('http://my_server').prefix_scheme
    ex = assert_raises(StandardError) { Wgit::Url.new('my_server').prefix_scheme(protocol: :ftp) }
    assert_equal 'protocol must be :http or :https, not :ftp', ex.message
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
    assert Wgit::Url.new('//fonts.googleapis.com').relative?
    assert Wgit::Url.new('doesntexist').relative?

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
    assert_equal 'Provide only one of: [:origin, :host, :domain, :brand]', e.message

    e = assert_raises(StandardError) do
      Wgit::Url.new('http://example.com').relative?(foo: 'http://example.com')
    end
    assert_equal 'Unknown opts param: :foo, use one of: [:origin, :host, :domain, :brand]', e.message

    e = assert_raises(StandardError) do
      Wgit::Url.new('http://example.com').relative?(foo: '/')
    end
    assert_equal 'Invalid opts param value, it must be absolute, containing a protocol scheme and domain (e.g. http://example.com): /', e.message

    e = assert_raises(StandardError) do
      Wgit::Url.new('http://example.com').relative?(brand: 'http://example')
    end
    assert_equal 'Invalid opts param value, it must be absolute, containing a protocol scheme and domain (e.g. http://example.com): http://example', e.message
  end

  def test_relative__with_origin
    # IRI's.
    assert Wgit::Url.new('https://www.über.com/about#top').relative? origin: 'https://www.über.com'
    refute Wgit::Url.new('https://www.über.com/about#top').relative? origin: 'https://www.überon.com'

    # URL's with paths (including slashes).
    assert Wgit::Url.new('http://www.google.co.uk/about.html').relative? origin: 'http://www.google.co.uk'
    refute Wgit::Url.new('https://www.google.co.uk').relative? origin: 'http://www.google.co.uk' # Diff protocol.
    refute Wgit::Url.new('http://www.google.co.uk/about.html').relative? origin: 'http://bing.com'
    assert Wgit::Url.new('http://www.google.co.uk').relative? origin: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/').relative? origin: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/').relative? origin: 'http://www.google.co.uk/'

    # Single slash URL's.
    assert Wgit::Url.new('/').relative? origin: 'http://www.google.co.uk'

    # Anchors/fragments.
    assert Wgit::Url.new('#about-us').relative? origin: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/about.html#about-us').relative? origin: 'http://www.google.co.uk'

    # Query string params.
    assert Wgit::Url.new('?foo=bar').relative? origin: 'http://www.google.co.uk'
    assert Wgit::Url.new('http://www.google.co.uk/about.html?foo=bar').relative? origin: 'http://www.google.co.uk'

    # URL specific.
    refute(
      Wgit::Url.new('http://www.example.com/search').relative?(origin: 'https://ftp.example.com')
    )
    refute(
      'http://www.example.com/search'.to_url.relative?(origin: 'https://ftp.example.com'.to_url)
    )
    refute(
      'http://www.example.com/search'.to_url.relative?(origin: 'https://ftp.example.co.uk'.to_url)
    )
    refute(
      'https://server.example.com'.to_url.relative?(origin: 'https://example.com/en'.to_url)
    )

    # Valid error scenarios.
    e = assert_raises(StandardError) do
      Wgit::Url.new('http://www.google.co.uk/about.html').relative? origin: 'bing.com'
    end
    assert_equal(
      'Invalid opts param value, it must be absolute, containing a protocol scheme and domain (e.g. http://example.com): bing.com',
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
      'Invalid opts param value, it must be absolute, containing a protocol scheme and domain (e.g. http://example.com): bing.com',
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
      'Invalid opts param value, it must be absolute, containing a protocol scheme and domain (e.g. http://example.com): bing.com',
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
      'Invalid opts param value, it must be absolute, containing a protocol scheme and domain (e.g. http://example.com): bing.com',
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
    assert_equal 'http://www.google.co.uk/about.html', Wgit::Url.new('http://www.google.co.uk/about').concat('.html')
    assert_equal 'http://example.com/', Wgit::Url.new('http://example.com').concat('/')
    assert_equal 'http://example.com/', Wgit::Url.new('http://example.com/').concat('/')
    assert_equal 'http://google.com/about/help', Wgit::Url.new('http://google.com/about').concat('help')
    assert_equal 'https://www.über?foo=bar', Wgit::Url.new('https://www.über').concat('?foo=bar')
    assert_instance_of Wgit::Url, Wgit::Url.new('https://www.über').concat('?foo=bar')

    e = assert_raises(StandardError) do
      Wgit::Url.new('https://www.über').concat('https://example.com')
    end
    assert_equal 'other must be relative', e.message
  end

  # Wgit::Url#+ is an alias for #concat but can result in an infinite loop so we test it.
  def test_plus
    url = 'http://twitter.com'.to_url
    concatted = url + 'about' + '#top'

    assert_equal 'http://twitter.com/about#top', concatted
    assert_instance_of Wgit::Url, concatted
  end

  def test_crawled=
    url = Wgit::Url.new 'http://www.google.co.uk'
    url.crawled = true

    assert url.crawled
    refute_nil url.date_crawled

    url = Wgit::Url.new 'http://www.google.co.uk', crawled: true, date_crawled: Time.now
    url.crawled = false

    refute url.crawled
    assert_nil url.date_crawled
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

  def test_to_addressable_uri
    assert_equal Addressable::URI, Wgit::Url.new('http://www.google.co.uk').to_addressable_uri.class

    uri = Wgit::Url.new('https://www.über.com/about#top').to_addressable_uri
    assert_equal Addressable::URI, uri.class
    assert_equal 'https://www.über.com/about#top', uri.to_s
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

  def test_to_port
    assert_equal '443', Wgit::Url.new('https://user:pass@www.example.com:443/about.html?q=blah&foo=bar#top').to_port
    assert_equal Wgit::Url, Wgit::Url.new('https://user:pass@www.example.com:443/about.html?q=blah&foo=bar#top').to_port.class
    assert_nil Wgit::Url.new('https://user:pass@www.example.com/about.html?q=blah&foo=bar#top').to_port

    assert_equal '3000', Wgit::Url.new('https://www.über.com:3000/about#top').to_port
    assert_equal Wgit::Url, Wgit::Url.new('https://www.über.com:3000/about#top').to_port.class
    assert_nil Wgit::Url.new('über').to_port
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

  def test_to_sub_domain
    assert_equal 'search.dev.scripts', Wgit::Url.new('https://search.dev.scripts.example.com/about.html').to_sub_domain
    assert_equal Wgit::Url, Wgit::Url.new('https://search.dev.scripts.example.com/about.html').to_sub_domain.class

    assert_equal 'search.dev.scripts', Wgit::Url.new('http://user:pass@search.dev.scripts.example.com/about.html').to_sub_domain
    assert_equal Wgit::Url, Wgit::Url.new('http://user:pass@search.dev.scripts.example.com/about.html').to_sub_domain.class

    assert_equal 'search.über.scripts', Wgit::Url.new('http://user:pass@search.über.scripts.example.com/about.html').to_sub_domain
    assert_equal Wgit::Url, Wgit::Url.new('http://user:pass@search.über.scripts.example.com/about.html?q=blah#top').to_sub_domain.class

    assert_equal 'www', Wgit::Url.new('http://www.example.com/about.html').to_sub_domain
    assert_equal Wgit::Url, Wgit::Url.new('http://www.example.com/about.html').to_sub_domain.class

    assert_nil Wgit::Url.new('/about.html').to_sub_domain
    assert_nil Wgit::Url.new('http://example.com').to_sub_domain
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

  def test_to_origin
    assert_equal 'https://dev.scripts.example.com:3000', Wgit::Url.new('https://dev.scripts.example.com:3000/about.html?q=blah&foo=bar#top').to_origin
    assert_equal Wgit::Url, Wgit::Url.new('https://dev.scripts.example.com:3000/about.html?q=blah&foo=bar#top').to_origin.class

    assert_equal 'http://dev.scripts.example.com', Wgit::Url.new('http://dev.scripts.example.com/about.html?q=blah&foo=bar#top').to_origin
    assert_equal Wgit::Url, Wgit::Url.new('http://dev.scripts.example.com/about.html?q=blah&foo=bar#top').to_origin.class

    assert_nil Wgit::Url.new('/about.html').to_origin
    assert_nil Wgit::Url.new('localhost:3000').to_origin

    assert_equal 'https://www.über.com:4567', Wgit::Url.new('https://www.über.com:4567/about#top').to_origin
    assert_equal Wgit::Url, Wgit::Url.new('https://www.über.com:4567/about#top').to_origin.class
    assert_nil Wgit::Url.new('über').to_origin
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

  def test_to_query
    url = Wgit::Url.new 'http://www.google.co.uk/about.html?q=ruby&page=2'
    assert_equal 'q=ruby&page=2', url.to_query
    assert_equal Wgit::Url, url.to_query.class

    url = Wgit::Url.new 'https://www.über.com/about?q=ruby&page=2#top'
    assert_equal 'q=ruby&page=2', url.to_query
    assert_equal Wgit::Url, url.to_query.class

    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_nil url.to_query
  end

  def test_to_query_hash
    url = Wgit::Url.new 'http://www.google.co.uk/about.html?q=ruby&page=2&limit=ten'
    assert_equal({ 'q' => 'ruby', 'page' => '2', 'limit' => 'ten' }, url.to_query_hash)
    assert_equal({ q: 'ruby', page: '2', limit: 'ten' }, url.to_query_hash(symbolize_keys: true))

    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_empty url.to_query_hash
  end

  def test_to_fragment
    url = Wgit::Url.new 'http://www.google.co.uk/about.html#about-us'
    assert_equal 'about-us', url.to_fragment
    assert_equal Wgit::Url, url.to_fragment.class

    url = Wgit::Url.new '#about-us'
    assert_equal 'about-us', url.to_fragment
    assert_equal Wgit::Url, url.to_fragment.class

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal 'top', url.to_fragment
    assert_equal Wgit::Url, url.to_fragment.class

    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_nil url.to_fragment
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

    url = Wgit::Url.new 'https://www.über.com/not_found.JPEG'
    assert_equal 'JPEG', url.to_extension
    assert_equal Wgit::Url, url.to_extension.class

    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_nil url.to_extension
  end

  def test_to_user
    url = Wgit::Url.new 'http://me:pass1@example.com/about?q=blah#bottom'
    assert_equal 'me', url.to_user
    assert_equal Wgit::Url, url.to_user.class

    url = Wgit::Url.new 'http://üser:pass1@example.com/about?q=blah#bottom'
    assert_equal 'üser', url.to_user
    assert_equal Wgit::Url, url.to_user.class

    url = Wgit::Url.new 'http://me@example.com/about?q=blah#bottom'
    assert_equal 'me', url.to_user
    assert_equal Wgit::Url, url.to_user.class

    url = Wgit::Url.new 'http://www.example.com/about?q=blah#bottom'
    assert_nil url.to_user

    url = Wgit::Url.new '/about'
    assert_nil url.to_user
  end

  def test_to_password
    url = Wgit::Url.new 'http://me:pass1@example.com/about?q=blah#bottom'
    assert_equal 'pass1', url.to_password
    assert_equal Wgit::Url, url.to_password.class

    url = Wgit::Url.new 'http://üser:passü@example.com/about?q=blah#bottom'
    assert_equal 'passü', url.to_password
    assert_equal Wgit::Url, url.to_password.class

    url = Wgit::Url.new 'http://me@example.com/about?q=blah#bottom'
    assert_nil url.to_password

    url = Wgit::Url.new 'http://www.example.com/about?q=blah#bottom'
    assert_nil url.to_password

    url = Wgit::Url.new '/about'
    assert_nil url.to_password
  end

  def test_omit_leading_slash
    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_equal 'http://www.google.co.uk', url.omit_leading_slash
    assert_equal Wgit::Url, url.omit_leading_slash.class

    url = Wgit::Url.new '/about.html'
    assert_equal 'about.html', url.omit_leading_slash
    assert_equal Wgit::Url, url.omit_leading_slash.class

    url = Wgit::Url.new '/über'
    assert_equal 'über', url.omit_leading_slash
    assert_equal Wgit::Url, url.omit_leading_slash.class
  end

  def test_omit_trailing_slash
    url = Wgit::Url.new 'http://www.google.co.uk'
    assert_equal 'http://www.google.co.uk', url.omit_trailing_slash
    assert_equal Wgit::Url, url.omit_trailing_slash.class

    url = Wgit::Url.new 'http://www.google.co.uk/'
    assert_equal 'http://www.google.co.uk', url.omit_trailing_slash
    assert_equal Wgit::Url, url.omit_trailing_slash.class

    url = Wgit::Url.new 'über/'
    assert_equal 'über', url.omit_trailing_slash
    assert_equal Wgit::Url, url.omit_trailing_slash.class
  end

  def test_omit_slashes
    url = Wgit::Url.new 'link.html'
    assert_equal 'link.html', url.omit_slashes
    assert_equal Wgit::Url, url.omit_slashes.class

    url = Wgit::Url.new '/link.html/'
    assert_equal 'link.html', url.omit_slashes
    assert_equal Wgit::Url, url.omit_slashes.class

    url = Wgit::Url.new '/über/'
    assert_equal 'über', url.omit_slashes
    assert_equal Wgit::Url, url.omit_slashes.class
  end

  def test_omit_base
    url = Wgit::Url.new 'http://google.com/search?q=foo#bar'
    assert_equal 'search?q=foo#bar', url.omit_base
    assert_equal Wgit::Url, url.omit_base.class

    url = Wgit::Url.new '/about.html'
    assert_equal 'about.html', url.omit_base
    assert_equal Wgit::Url, url.omit_base.class

    url = Wgit::Url.new '/about.html#hello/'
    assert_equal 'about.html#hello', url.omit_base
    assert_equal Wgit::Url, url.omit_base.class

    url = Wgit::Url.new '/about.html/hello?a=b&b=c#about'
    assert_equal 'about.html/hello?a=b&b=c#about', url.omit_base
    assert_equal Wgit::Url, url.omit_base.class

    url = Wgit::Url.new '/'
    assert_equal url, url.omit_base
    assert_equal Wgit::Url, url.omit_base.class

    url = Wgit::Url.new 'https://google.com/'
    assert_equal url, url.omit_base
    assert_equal Wgit::Url, url.omit_base.class

    url = Wgit::Url.new 'https://google.com'
    assert_equal url, url.omit_base
    assert_equal Wgit::Url, url.omit_base.class

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal 'about#top', url.omit_base
    assert_equal Wgit::Url, url.omit_base.class
  end

  def test_omit_origin
    url = Wgit::Url.new 'http://google.com:81/search?q=foo#bar'
    assert_equal 'search?q=foo#bar', url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class

    url = Wgit::Url.new 'http://google.com/search?q=foo#bar'
    assert_equal 'search?q=foo#bar', url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class

    url = Wgit::Url.new '/about.html'
    assert_equal 'about.html', url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class

    url = Wgit::Url.new '/about.html#hello/'
    assert_equal 'about.html#hello', url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class

    url = Wgit::Url.new '/about.html/hello?a=b&b=c#about'
    assert_equal 'about.html/hello?a=b&b=c#about', url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class

    url = Wgit::Url.new '/'
    assert_equal url, url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class

    url = Wgit::Url.new 'https://google.com/'
    assert_equal url, url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class

    url = Wgit::Url.new 'https://google.com'
    assert_equal url, url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class

    url = Wgit::Url.new 'https://google.com:81/'
    assert_equal url, url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class

    url = Wgit::Url.new 'https://google.com:81'
    assert_equal url, url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal 'about#top', url.omit_origin
    assert_equal Wgit::Url, url.omit_origin.class
  end

  def test_omit_query
    url = Wgit::Url.new 'http://google.com/search?q=hello&foo=bar'
    assert_equal 'http://google.com/search', url.omit_query
    assert_equal Wgit::Url, url.omit_query.class

    url = Wgit::Url.new '/about.html'
    assert_equal '/about.html', url.omit_query
    assert_equal Wgit::Url, url.omit_query.class

    url = Wgit::Url.new '/about.html?q=hello&foo=bar'
    assert_equal '/about.html', url.omit_query
    assert_equal Wgit::Url, url.omit_query.class

    url = Wgit::Url.new '/about.html/hello?a=b&b=c#about'
    assert_equal '/about.html/hello#about', url.omit_query
    assert_equal Wgit::Url, url.omit_query.class

    url = Wgit::Url.new '/about.html/hello#about?a=b&b=c' # Invalid fragment.
    assert_equal '/about.html/hello#about?a=b&b=c', url.omit_query
    assert_equal Wgit::Url, url.omit_query.class

    url = Wgit::Url.new '/'
    assert_equal url, url.omit_query
    assert_equal Wgit::Url, url.omit_query.class

    url = Wgit::Url.new '?q=hello&foo=bar'
    assert_empty url.omit_query
    assert_equal Wgit::Url, url.omit_query.class

    url = Wgit::Url.new 'https://google.com/'
    assert_equal url, url.omit_query
    assert_equal Wgit::Url, url.omit_query.class

    url = Wgit::Url.new 'https://google.com'
    assert_equal url, url.omit_query
    assert_equal Wgit::Url, url.omit_query.class

    iri_omit_fragment = 'https://www.über.com/about'
    url = Wgit::Url.new iri_omit_fragment + '?q=hello'
    assert_equal iri_omit_fragment, url.omit_query
    assert_equal Wgit::Url, url.omit_query.class
  end

  def test_omit_fragment
    url = Wgit::Url.new 'http://google.com/search?q=foo#bar'
    assert_equal 'http://google.com/search?q=foo', url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class

    url = Wgit::Url.new '/about.html'
    assert_equal '/about.html', url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class

    url = Wgit::Url.new '/about.html#hello/'
    assert_equal '/about.html', url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class

    url = Wgit::Url.new '/about.html/hello?a=b&b=c#about'
    assert_equal '/about.html/hello?a=b&b=c', url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class

    url = Wgit::Url.new '/about.html/hello#about?a=b&b=c' # Invalid fragment.
    assert_equal '/about.html/hello', url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class

    url = Wgit::Url.new '/'
    assert_equal url, url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class

    url = Wgit::Url.new '#about'
    assert_empty url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class

    url = Wgit::Url.new '/about#'
    assert_equal '/about', url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class

    url = Wgit::Url.new 'https://google.com/'
    assert_equal url, url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class

    url = Wgit::Url.new 'https://google.com'
    assert_equal url, url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class

    url = Wgit::Url.new 'https://www.über.com/about#top'
    assert_equal 'https://www.über.com/about', url.omit_fragment
    assert_equal Wgit::Url, url.omit_fragment.class
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

  def test_fragment?
    url = Wgit::Url.new '#'
    assert url.fragment?

    url = Wgit::Url.new '?q=hello'
    refute url.fragment?

    url = Wgit::Url.new '/public#top'
    refute url.fragment?

    url = Wgit::Url.new 'http://example.com#top'
    refute url.fragment?

    url = Wgit::Url.new 'http://example.com/home#top'
    refute url.fragment?
  end

  def test_to_h
    mongo_doc = {
      'url' => 'http://www.google.co.uk',
      'crawled' => true,
      'date_crawled' => Time.now,
      'crawl_duration' => 1.5
    }
    assert_equal mongo_doc, Wgit::Url.new(mongo_doc).to_h
  end
end
