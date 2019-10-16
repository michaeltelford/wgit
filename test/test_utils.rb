require_relative 'helpers/test_helper'

# We use a class rather than a Struct because a Struct instance doesn't
# have instance_variables which Wgit::Utils.to_h uses.
class Person
  attr_accessor :name, :age, :height

  def initialize
    @name   = 'Bob'
    @age    = 45
    @height = "5'11"
  end
end

# Test class for utility module functions.
class TestUtils < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup; end

  def test_to_h
    h = Wgit::Utils.to_h Person.new, ignore: ['@height']
    assert_equal({
                   'name' => 'Bob',
                   'age' => 45
                 }, h)
  end

  def test_to_h__with_symbols
    h = Wgit::Utils.to_h Person.new, ignore: ['@height'], use_strings_as_keys: false
    assert_equal({
                   name: 'Bob',
                   age: 45
                 }, h)
  end

  def test_each
    str = %w[hello goodbye]
    Wgit::Utils.each(str) { |el| el.replace(el + 1.to_s) }
    assert_equal %w[hello1 goodbye1], str

    str = 'hello'
    Wgit::Utils.each(str) { |el| el.replace(el + 1.to_s) }
    assert_equal 'hello1', str
  end

  def test_fetch
    assert_equal 'bar', Wgit::Utils.fetch({ foo: 'bar' }, :foo)
    assert_equal 'bar', Wgit::Utils.fetch({ foo: 'bar' }, 'foo')
    assert_equal 'bar', Wgit::Utils.fetch({ foo: 'bar' }, 'Foo')
    assert_equal 'bar', Wgit::Utils.fetch({ foo: 'bar' }, 'FOO')
    assert_equal 'bar', Wgit::Utils.fetch({ foo: 'bar' }, 'fOo')
    assert_equal 'taz', Wgit::Utils.fetch({ foo: 'bar' }, :blah, 'taz')
    assert_nil Wgit::Utils.fetch({ foo: 'bar' }, :blah)
  end

  def test_format_sentence_length
    sentence_limit = 10

    # Short sentence.
    sentence = 'For what'
    result = Wgit::Utils.format_sentence_length sentence.dup, 2, sentence_limit
    assert_equal sentence, result

    # Long sentence: index near start.
    sentence = 'For what of the flower if not for soil beneath it?'
    result = Wgit::Utils.format_sentence_length sentence.dup, 5, sentence_limit
    assert_equal 'For what o', result

    # Long sentence: index near end.
    result = Wgit::Utils.format_sentence_length sentence.dup, 48, sentence_limit
    assert_equal 'eneath it?', result

    # Long sentence: index near middle.
    result = Wgit::Utils.format_sentence_length sentence.dup, 23, sentence_limit
    assert_equal 'ower if no', result

    # Return full sentence.
    sentence = "For what of the flower if not for soil beneath it?\
                For what of the flower if not for soil beneath it?\
                For what of the flower if not for soil beneath it?"
    result = Wgit::Utils.format_sentence_length sentence.dup, 5, 0
    assert_equal sentence, result
  end

  def test_printf_search_results
    # Setup the test results data.
    query   = 'Everest'
    results = []

    5.times do
      doc_hash        = Wgit::DatabaseDevData.doc
      doc_hash['url'] = 'http://altitudejunkies.com/everest.html'

      doc = Wgit::Document.new(doc_hash)
      doc.search!(query)

      results << doc
    end

    # Setup a buffer to record the output.
    buffer = StringIO.new
    Wgit::Utils.printf_search_results(results, stream: buffer)

    assert_equal printf_expected_output, buffer.string
  end

  def test_process_str
    s = ' hello world '
    s2 = Wgit::Utils.process_str s

    assert_equal s.strip, s
    assert_equal s2, s
  end

  def test_process_arr
    a = ['', true, nil, true, false, ' hello world ']
    a2 = Wgit::Utils.process_arr a
    expected = [true, false, 'hello world']

    assert_equal expected, a
    assert_equal expected, a2
  end

  private

  def printf_expected_output
    <<~TEXT
    Altitude Junkies | Everest
    Everest, Highest Peak, High Altitude, Altitude Junkies
    e Summit for the hugely successful IMAX Everest film from the 1996 spring season
    http://altitudejunkies.com/everest.html

    Altitude Junkies | Everest
    Everest, Highest Peak, High Altitude, Altitude Junkies
    e Summit for the hugely successful IMAX Everest film from the 1996 spring season
    http://altitudejunkies.com/everest.html

    Altitude Junkies | Everest
    Everest, Highest Peak, High Altitude, Altitude Junkies
    e Summit for the hugely successful IMAX Everest film from the 1996 spring season
    http://altitudejunkies.com/everest.html

    Altitude Junkies | Everest
    Everest, Highest Peak, High Altitude, Altitude Junkies
    e Summit for the hugely successful IMAX Everest film from the 1996 spring season
    http://altitudejunkies.com/everest.html

    Altitude Junkies | Everest
    Everest, Highest Peak, High Altitude, Altitude Junkies
    e Summit for the hugely successful IMAX Everest film from the 1996 spring season
    http://altitudejunkies.com/everest.html

    TEXT
  end
end
