require "minitest/autorun"
require 'minitest/pride'
require_relative "helpers/test_helper"

class TestGem < Minitest::Test
  include TestHelper
  
  # Runs before every test.
  def setup
  end
  
  # Test the wgit.rb file loads the API correctly.
  def test_require
    require('wgit')
    pass
  rescue
    flunk
  end
end
