require "minitest/autorun"
require_relative "helpers/test_helper"
require_relative "../lib/wgit/assertable"
require_relative "../lib/wgit/url"
require_relative "../lib/wgit/core_ext"

# @author Michael Telford
class TestCoreExt < Minitest::Test
  include TestHelper
  include Wgit::Assertable
  
  # Runs before every test.
  def setup
  end
  
  def test_string_to_url
    s = "http://www.google.co.uk"
    url = s.to_url
    assert_type url, Wgit::Url
    assert_equal s, url
  end
end
