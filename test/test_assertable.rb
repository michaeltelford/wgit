require "minitest/autorun"
require_relative "../lib/pinch/assertable"

# @author Michael Telford
class TestAssertable < Minitest::Test
    include Assertable
    
    def setup
        # Runs before every test.
        @s  = "Hello World!"
        @a  = [1, 2, 3]
        @a2 = [1, true, "Boom!"]
    end
    
    def test_assert_type_pass
        assert_equal @s, assert_type(@s, String)
    rescue RuntimeError => ex
        flunk ex.message
    end
    
    def test_assert_type_fail
        ex = assert_raises RuntimeError do
            assert_type @s, Fixnum
        end
        assert_equal "Expected: Fixnum, Actual: String", ex.message
    end
    
    def test_assert_type_pass2
        assert_equal @a, assert_type(@a, [Array, String])
    rescue RuntimeError => ex
        flunk ex.message
    end
    
    def test_assert_type_fail2
        ex = assert_raises RuntimeError do
            assert_type @a, [TrueClass, Fixnum], "An Array is expected"
        end
        assert_equal "An Array is expected", ex.message
    end
    
    def test_assert_arr_types_pass
        assert_equal @a2, assert_arr_types(@a2, [Fixnum, TrueClass, String])
    rescue RuntimeError => ex
        flunk ex.message
    end
    
    def test_assert_arr_types_fail
        ex = assert_raises RuntimeError do
            assert_arr_types @a2, [Fixnum, String]
        end
        assert_equal "Expected: [Fixnum, String], Actual: TrueClass", ex.message
    end
end
