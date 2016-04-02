require "minitest/autorun"
require_relative "test_helper"

# @author Michael Telford
class TestGem < Minitest::Test
    include TestHelper
    
    def setup
        # Runs before every test.
    end
    
    # Test the pinch.rb file loads the API correctly.
    def test_require
        assert require('pinch')
    end
end
