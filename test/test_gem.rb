# frozen_string_literal: true

require_relative 'helpers/test_helper'

# Test class for requiring the wgit gem.
class TestGem < TestHelper
  # Runs before every test.
  def setup; end

  # Test the wgit.rb file loads the API correctly.
  def test_require
    require('wgit')
    pass
  rescue StandardError
    flunk
  end
end
