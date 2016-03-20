require "minitest/autorun"
require_relative "../lib/pinch/utils"

# @author Michael Telford
class TestUtils < Minitest::Test
    def setup
        # Runs before every test.
        @person = Person.new
        @to_h_result = {
            :name => "Bob",
            :age => 45
        }
    end
    
    def test_to_h
        h = Utils.to_h @person, [:@height]
        assert_equal @to_h_result, h
    rescue RuntimeError => ex
        flunk ex.message
    end
end

class Person
    attr_accessor :name, :age, :height
    def initialize
        @name = "Bob"
        @age = 45
        @height = "5'11"
    end
end
