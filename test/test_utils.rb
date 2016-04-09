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
        h = Utils.to_h @person, [:@height]
        assert_equal @to_h_result, h
    end
    
    def test_each
        str = ["hello", "goodbye"]
        Utils.each(str) { |el| el.replace(el + 1.to_s) }
        assert_equal ["hello1", "goodbye1"], str
        
        str = "hello"
        Utils.each(str) { |el| el.replace(el + 1.to_s) }
        assert_equal "hello1", str
    end
    
    def p_debug
        flunk "TODO: Send output to a file and assert the contents"
    end
    
    def test_format_sentence_length
        sentence_limit = 10
        
        # Short sentence.
        sentence = "For what"
        result = Utils.format_sentence_length sentence, 2, sentence_limit
        assert_equal sentence, result
        
        # Long sentence: index near start.
        sentence = "For what of the flower if not for soil beneath it?"
        result = Utils.format_sentence_length sentence.dup, 5, sentence_limit
        assert_equal "For what o", result
        
        # Long sentence: index near end.
        result = Utils.format_sentence_length sentence.dup, 48, sentence_limit
        assert_equal "eneath it?", result
        
        # Long sentence: index near middle.
        result = Utils.format_sentence_length sentence.dup, 23, sentence_limit
        assert_equal "ower if no", result
    end
    
    def test_printf_search_results
        flunk "TODO: Send output to a file and assert the contents"
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
