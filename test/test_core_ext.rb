# frozen_string_literal: true

require_relative 'helpers/test_helper'

# Test class for the Ruby core extension methods.
class TestCoreExt < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_string_to_url
    s = 'http://www.google.co.uk'
    url = s.to_url
    assert_instance_of Wgit::Url, url
    assert_equal s, url
    assert_equal url.object_id, url.to_url.object_id
  end

  def test_array_to_urls
    url_strs = [
      'http://altitudejunkies.com',
      'http://www.mountainmadness.com',
      'http://www.adventureconsultants.com'
    ]
    urls = url_strs.to_urls

    assert url_strs.all? { |url| url.instance_of? String }
    assert urls.all? { |url| url.instance_of? Wgit::Url }

    url_strs = [
      'http://altitudejunkies.com',
      true,
      'http://www.adventureconsultants.com'
    ]
    urls = url_strs.to_urls

    assert url_strs.first.instance_of? String
    refute urls.all? { |url| url.instance_of? Wgit::Url }
    assert urls.first.instance_of? Wgit::Url
    assert urls[1].instance_of? TrueClass
    assert urls.last.instance_of? Wgit::Url
  end

  def test_array_to_urls!
    urls = [
      'http://altitudejunkies.com',
      'http://www.mountainmadness.com',
      'http://www.adventureconsultants.com'
    ].to_urls!

    assert urls.all? { |url| url.instance_of? Wgit::Url }

    urls = [
      'http://altitudejunkies.com',
      true,
      'http://www.adventureconsultants.com'
    ].to_urls!

    refute urls.all? { |url| url.instance_of? Wgit::Url }
    assert urls.first.instance_of? Wgit::Url
    assert urls[1].instance_of? TrueClass
    assert urls.last.instance_of? Wgit::Url
  end
end
