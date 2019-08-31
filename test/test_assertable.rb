# frozen_string_literal: true

require_relative 'helpers/test_helper'

# Test class for the Assertable funcs.
class TestAssertable < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup
    @s  = 'Hello World!'
    @a  = [1, 2, 3]
    @a2 = [1, true, 'Boom!']
  end

  def test_assert_types_pass
    assert_equal @s, assert_types(@s, String)
    assert_equal @a, assert_types(@a, [Array, String])
  end

  def test_assert_types_fail
    ex = assert_raises RuntimeError do
      assert_types @s, Integer
    end
    assert_equal 'Expected: Integer, Actual: String', ex.message

    ex = assert_raises RuntimeError do
      assert_types @a, [TrueClass, Integer], 'An Array is expected'
    end
    assert_equal 'An Array is expected', ex.message
  end

  def test_assert_arr_types_pass
    assert_equal @a2, assert_arr_types(@a2, [Integer, TrueClass, String])
  end

  def test_assert_arr_types_fail
    ex = assert_raises RuntimeError do
      assert_arr_types @a2, [Integer, String]
    end
    s = 'Expected: [Integer, String], Actual: TrueClass'
    assert_equal s, ex.message
  end

  def test_assert_respond_to_pass
    objs = [@s, @a]
    assert_equal objs, assert_respond_to(objs, %i[equal? include?])
  end

  def test_assert_respond_to_fail
    objs = [@s, @a]
    ex = assert_raises RuntimeError do
      assert_equal objs, assert_respond_to(objs, %i[equal? each])
    end
    assert_equal(
      "String (Hello World!) doesn't respond_to? [:equal?, :each]",
      ex.message
    )
  end

  def test_assert_respond_to_single_method
    objs = [@s, @a]
    assert_equal objs, assert_respond_to(objs, :length)
  end

  def assert_required_keys_pass
    hash = { 'NAME': 'Mick', 'AGE': 30 }
    assert_equal hash, assert_required_keys(hash, %w[NAME AGE])
  end

  def assert_required_keys_fail
    hash = { 'NAME': 'Mick', 'AGE': 30 }
    ex = assert_raises KeyError do
      assert_required_keys(hash, %w[NAME ADDRESS])
    end
    assert_equal(
      'Some or all of the required keys are not present: NAME, ADDRESS',
      ex.message
    )
  end
end
