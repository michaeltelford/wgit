require "minitest/autorun"
require_relative "test_helper"

# @author Michael Telford
class TestLoad < Minitest::Test
    include TestHelper
    
    def setup
        # Runs before every test.
    end
    
    def test_load
        # TODO: Supress the load output by writing it to a file.
        #assert load 'load.rb'
        flunk "TODO: test_load with suppressed output"
    end
end
