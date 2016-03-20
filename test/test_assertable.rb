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
    
    def test_assert_types_pass
        assert_equal @s, assert_types(@s, String)
    rescue RuntimeError => ex
        flunk ex.message
    end
    
    def test_assert_types_fail
        ex = assert_raises RuntimeError do
            assert_types @s, Fixnum
        end
        assert_equal "Expected: Fixnum, Actual: String", ex.message
    end
    
    def test_assert_types_pass2
        assert_equal @a, assert_types(@a, [Array, String])
    rescue RuntimeError => ex
        flunk ex.message
    end
    
    def test_assert_types_fail2
        ex = assert_raises RuntimeError do
            assert_types @a, [TrueClass, Fixnum], "An Array is expected"
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
        s = "Expected: [Fixnum, String], Actual: TrueClass"
        assert_equal s, ex.message
    end
    
    def test_assert_respond_to_pass
        objs = [@s, @a]
        assert_equal objs, assert_respond_to(objs, [:equal?, :include?])
    rescue RuntimeError => ex
        flunk ex.message
    end
    
    def test_assert_respond_to_fail
        objs = [@s, @a]
        ex = assert_raises RuntimeError do
            assert_equal objs, assert_respond_to(objs, [:equal?, :each])
        end
        assert_equal(
        "String (Hello World!) doesn't respond_to? [:equal?, :each]", 
        ex.message)
    end
end