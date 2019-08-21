require_relative "helpers/test_helper"

# Test class for Url methods.
class TestUrl < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup
    @url_str = "http://www.google.co.uk"
    @bad_url_str = "my_server"
    @link = "/about.html"
    @url_str_link = "#{@url_str}#{@link}"
    @url_str_anchor = "#{@url_str_link}#about-us"
    @url_str_query = "#{@url_str_link}?foo=bar"
    @iri = "https://www.über.com/about#top"
    @time_stamp = Time.new
    @mongo_doc_dup = {
      "url" => @url_str,
      "crawled" => true,
      "date_crawled" => @time_stamp
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
                                                @bad_url_str.dup, true)
    assert_equal "http://#{@bad_url_str}", Wgit::Url.prefix_protocol(
                                                @bad_url_str.dup)
  end

  def test_relative_link?
    # Common type URL's.
    assert Wgit::Url.new(@link).is_relative?
    refute Wgit::Url.new(@url_str).is_relative?

    # IRI's.
    assert Wgit::Url.new('/über').is_relative?
    refute Wgit::Url.new(@iri).is_relative?
    assert Wgit::Url.new(@iri).is_relative? base: 'https://www.über.com'
    refute Wgit::Url.new(@iri).is_relative? base: 'https://www.überon.com'

    # URL's with paths (including slashes).
    assert Wgit::Url.new(@url_str_link).is_relative? base: @url_str
    assert Wgit::Url.new('https://www.google.co.uk').is_relative? base: @url_str # Diff protocol.
    refute Wgit::Url.new(@url_str_link).is_relative? base: 'http://bing.com'
    assert Wgit::Url.new(@url_str).is_relative? base: @url_str
    assert Wgit::Url.new(@url_str + '/').is_relative? base: @url_str
    assert Wgit::Url.new(@url_str + '/').is_relative? base: @url_str + '/'

    # Single slash URL's.
    assert Wgit::Url.new('/').is_relative?
    assert Wgit::Url.new('/').is_relative? base: @url_str

    # Anchors/fragments.
    assert Wgit::Url.new('#about-us').is_relative?
    refute Wgit::Url.new(@url_str_anchor).is_relative?
    assert Wgit::Url.new(@url_str_anchor).is_relative? base: @url_str

    # Query string params.
    assert Wgit::Url.new('?foo=bar').is_relative?
    refute Wgit::Url.new(@url_str_query).is_relative?
    assert Wgit::Url.new(@url_str_query).is_relative? base: @url_str

    # Valid error scenarios.
    assert_raises(RuntimeError) do
      Wgit::Url.new(@url_str_link).is_relative? base: 'bing.com'
    end
    assert_raises(RuntimeError) { Wgit::Url.new('').is_relative? }
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
    assert_equal "www.google.co.uk", Wgit::Url.new(@url_str_link).to_host
    assert_equal Wgit::Url, Wgit::Url.new(@url_str_link).to_host.class
    assert_nil Wgit::Url.new(@link).to_host

    assert_equal "www.über.com", Wgit::Url.new(@iri).to_host
    assert_equal Wgit::Url, Wgit::Url.new(@iri).to_host.class
    assert_nil Wgit::Url.new('über').to_host
  end

  def test_to_base
    assert_equal @url_str, Wgit::Url.new(@url_str_link).to_base
    assert_equal Wgit::Url, Wgit::Url.new(@url_str_link).to_base.class
    assert_nil Wgit::Url.new(@link).to_base

    assert_equal 'https://www.über.com', Wgit::Url.new(@iri).to_base
    assert_equal Wgit::Url, Wgit::Url.new(@iri).to_base.class
    assert_nil Wgit::Url.new('über').to_base
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
    assert_equal 'q=ruby&page=2', url.to_query_string
    assert_equal Wgit::Url, url.to_query_string.class

    url = Wgit::Url.new 'https://www.über.com/about?q=ruby&page=2'
    assert_equal 'q=ruby&page=2', url.to_query_string
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

  def test_to_h
    assert_equal @mongo_doc_dup, Wgit::Url.new(@mongo_doc_dup).to_h
  end
end
