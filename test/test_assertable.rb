# frozen_string_literal: true

require_relative 'helpers/test_helper'

# Test class for the Assertable module functions.
class TestAssertable < TestHelper
  include Wgit::Assertable

  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_assert_types__pass
    assert_equal 'Hello World!', assert_types('Hello World!', String)
    assert_equal [1, 2, 3], assert_types([1, 2, 3], [Array, String])
    assert_equal '/about', assert_types('/about'.to_url, String)
  end

  def test_assert_types__fail
    e = assert_raises(StandardError) { assert_types 'Hello World!', Integer }
    assert_equal 'Expected: Integer, Actual: String', e.message

    e = assert_raises StandardError do
      assert_types [1, 2, 3], [TrueClass, Integer], 'An Array is expected'
    end
    assert_equal 'An Array is expected', e.message
  end

  def test_assert_arr_types__pass
    assert_equal [1, true, 'Boom!'], assert_arr_types([1, true, 'Boom!'], [Integer, TrueClass, String])
    assert_equal [1, true, '/about'], assert_arr_types([1, true, '/about'.to_url], [Integer, TrueClass, String])
  end

  def test_assert_arr_types__fail
    e = assert_raises StandardError do
      assert_arr_types [1, true, 'Boom!'], [Integer, String]
    end
    s = 'Expected: [Integer, String], Actual: TrueClass'

    assert_equal s, e.message
  end

  def test_assert_arr_types__non_enumerable
    e = assert_raises StandardError do
      assert_arr_type 'non enumerable', Integer
    end
    s = 'Expected an Enumerable responding to #each, not: String'

    assert_equal s, e.message
  end

  def test_assert_respond_to__pass
    objs = ['Hello World!', [1, 2, 3]]

    assert_equal objs, assert_respond_to(objs, %i[equal? include?])
  end

  def test_assert_respond_to__fail
    objs = ['Hello World!', [1, 2, 3]]

    e = assert_raises StandardError do
      assert_equal objs, assert_respond_to(objs, %i[equal? each])
    end
    assert_equal(
      "String (Hello World!) doesn't respond_to? [:equal?, :each]",
      e.message
    )
  end

  def test_assert_respond_to__single_method
    objs = ['Hello World!', [1, 2, 3]]

    assert_equal objs, assert_respond_to(objs, :length)
  end

  def assert_required_keys__pass
    hash = { 'NAME': 'Mick', 'AGE': 30 }

    assert_equal hash, assert_required_keys(hash, %w[NAME AGE])
  end

  def assert_required_keys__fail
    hash = { 'NAME': 'Mick', 'AGE': 30 }

    e = assert_raises KeyError { assert_required_keys(hash, %w[NAME ADDRESS]) }
    assert_equal(
      'Some or all of the required keys are not present: NAME, ADDRESS',
      e.message
    )
  end
end
