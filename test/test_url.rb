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
  
  def test_initialize_from_mongo_doc
    url = Wgit::Url.new @mongo_doc_dup
    assert_equal @url_str, url
    assert url.crawled
    assert_equal @time_stamp, url.date_crawled
  end
  
  def test_validate
    Wgit::Url.validate @url_str
    assert_raises(RuntimeError) { Wgit::Url.validate @bad_url_str }
  end
  
  def test_valid?
    assert Wgit::Url.valid? @url_str
    refute Wgit::Url.valid? @bad_url_str
  end
  
  def test_prefix_protocol
    assert_equal "https://#{@bad_url_str}", Wgit::Url.prefix_protocol(
                                                @bad_url_str.dup, true)
    assert_equal "http://#{@bad_url_str}", Wgit::Url.prefix_protocol(
                                                @bad_url_str.dup)
  end
  
  def test_relative_link?
    assert Wgit::Url.relative_link? @link
    refute Wgit::Url.relative_link? @url_str
    
    assert Wgit::Url.relative_link? @url_str_link, base: @url_str
    refute Wgit::Url.relative_link? @url_str_link, base: "http://bing.com"

    assert Wgit::Url.relative_link? "/"
    assert Wgit::Url.relative_link? "/", base: @url_str

    assert_raises(RuntimeError) do
      Wgit::Url.relative_link? @url_str_link, base: "bing.com"
    end

    assert Wgit::Url.new(@url_str_link).relative_link?(base: @url_str)
    refute Wgit::Url.new(@url_str_link).relative_link?(base: "http://bing.com")
  end
  
  def test_concat
    assert_equal @url_str_link, Wgit::Url.concat(@url_str, @link)
    assert_equal @url_str_link, Wgit::Url.concat(@url_str, @link[1..-1])
  end
  
  def test_crawled=
    url = Wgit::Url.new @url_str
    url.crawled = true
    assert url.crawled
    assert url.crawled?
  end
  
  def test_to_uri
    assert_equal URI::HTTP, Wgit::Url.new(@url_str).to_uri.class
  end
  
  def test_to_url
    url = Wgit::Url.new @url_str
    assert_equal url.object_id, url.to_url.object_id
    assert_equal url, url.to_url
    assert_equal Wgit::Url, url.to_url.class
  end

  def test_to_scheme
    url = Wgit::Url.new @url_str
    assert_equal 'http', url.to_scheme
    assert_equal Wgit::Url, url.to_url.class
  end
  
  def test_to_host
    assert_equal "www.google.co.uk", Wgit::Url.new(@url_str_link).to_host
    assert_equal Wgit::Url, Wgit::Url.new(@url_str_link).to_host.class
  end
  
  def test_to_base
    assert_raises(RuntimeError) { Wgit::Url.new(@link).to_base }
    assert_equal @url_str, Wgit::Url.new(@url_str_link).to_base
    assert_equal Wgit::Url, Wgit::Url.new(@url_str_link).to_base.class
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
  end

  def test_to_query_string
    url = Wgit::Url.new @url_str_link + '?q=ruby&page=2'
    assert_equal 'q=ruby&page=2', url.to_query_string
    assert_equal Wgit::Url, url.to_url.class
  end
  
  def test_to_h
    assert_equal @mongo_doc_dup, Wgit::Url.new(@mongo_doc_dup).to_h
  end
end
