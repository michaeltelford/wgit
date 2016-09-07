require "minitest/autorun"
require 'minitest/pride'
require_relative "helpers/test_helper"

# @author Michael Telford
class TestGem < Minitest::Test
    include TestHelper
    
    def setup
        # Runs before every test.
    end
    
    # Test the wgit.rb file loads the API correctly.
    def test_require
        assert require('wgit')
    end
end
