require "minitest/autorun"
require 'minitest/pride'
require_relative "helpers/test_helper"

# @author Michael Telford
class TestLoad < Minitest::Test
    include TestHelper
    
    # Runs before every test.
    def setup
    end
    
    def test_load
        # TODO: Supress the load output by writing it to a file.
        assert load 'load.rb'
    end
end
