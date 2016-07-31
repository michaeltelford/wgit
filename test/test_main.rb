require "minitest/autorun"
require_relative "helpers/test_helper"

# @author Michael Telford
class TestMain < Minitest::Test
    include TestHelper
    
    def setup
        # Runs before every test.
    end
    
    def test_crawl_the_web
        # TODO: Refactor main into lib and bin exec, then unit test.
        flunk "TODO: Refactor main into lib and bin exec, then unit test"
    end
end
