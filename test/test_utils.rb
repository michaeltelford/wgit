require "minitest/autorun"
require_relative "test_helper"
require_relative "../lib/pinch/utils"

# @author Michael Telford
class TestUtils < Minitest::Test
    include TestHelper
    
    def setup
        # Runs before every test.
        @person = Person.new
        @to_h_result = {
            :name => "Bob",
            :age => 45
        }
    end
    
    def test_to_h
        flunk_ex self do
            h = Utils.to_h @person, [:@height]
            assert_equal @to_h_result, h
        end
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
