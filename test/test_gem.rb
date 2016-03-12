require "minitest/autorun"

# @author Michael Telford
class TestGem < Minitest::Test
    def setup
        # Runs before every test.
    end
    
    # Test the pinch.rb loads the API correctly.
    def test_require
        assert_equal true, require('pinch')
    end
end
