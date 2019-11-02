require_relative 'helpers/test_helper'

# Test class for the Response methods.
class TestResponse < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_initialize
    r = Wgit::Response.new

    assert_empty r.body
    assert_empty r.headers
    assert_empty r.redirections
    assert_equal 0.0, r.total_time
  end

  def test_add_total_time
    r = Wgit::Response.new

    assert_equal 0.2, r.add_total_time(0.2)
    assert_equal 0.5, r.add_total_time(0.3)
  end

  def test_body_equals
    r = Wgit::Response.new

    r.body = nil
    assert_equal '', r.body

    r.body = 'hello world'
    assert_equal 'hello world', r.body
  end

  def test_body_or_nil
    r = Wgit::Response.new
    assert_nil r.body_or_nil

    r.body = 'hello world'
    assert_equal 'hello world', r.body
  end

  def test_failure?
    r = Wgit::Response.new

    r.status = 500
    assert r.failure?

    r.status = 200
    refute r.failure?
  end

  def test_headers_equals
    r = Wgit::Response.new

    r.headers = { 'Content-Type' => 'text/html' }
    assert_equal({ content_type: 'text/html' }, r.headers)
  end

  def test_ok?
    r = Wgit::Response.new

    r.status = 204
    refute r.ok?

    r.status = 200
    assert r.ok?
  end

  def test_redirect?
    r = Wgit::Response.new
    refute r.redirect?

    r.status = 200
    refute r.redirect?

    r.status = 301
    assert r.redirect?
  end

  def test_redirect_count
    r = Wgit::Response.new
    r.redirections['a'] = 'foo'
    r.redirections['b'] = 'bar'

    assert_equal 2, r.redirect_count
  end

  def test_size
    r = Wgit::Response.new
    assert_equal 0, r.size

    r.body = 'hello world'
    assert_equal 11, r.size
  end

  def test_status_equals
    r = Wgit::Response.new

    r.status = 0
    assert_nil r.status

    r.status = 200
    assert_equal 200, r.status
  end

  def test_success?
    r = Wgit::Response.new
    refute r.success?

    r.status = 200
    assert r.success?

    r.status = 301
    refute r.success?
  end
end
