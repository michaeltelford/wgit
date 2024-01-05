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

  def test_pprint_search_results
    # Setup the test results data.
    query   = 'Everest'
    results = []

    5.times do
      doc_hash        = DatabaseTestData.doc
      doc_hash['url'] = 'http://altitudejunkies.com/everest.html'

      doc = Wgit::Document.new(doc_hash)
      doc.search!(query)

      results << doc
    end

    # Setup a buffer to record the output.
    buffer = StringIO.new
    num_results = Wgit::Utils.pprint_search_results(results, stream: buffer)

    assert_equal 5, num_results
    assert_equal printf_output__results, buffer.string
  end

  def test_pprint_search_results__empty
    # Setup the test results data.
    results = []

    # Setup a buffer to record the output.
    buffer = StringIO.new
    num_results = Wgit::Utils.pprint_search_results(results, stream: buffer)

    assert_equal 0, num_results
    assert_equal '', buffer.string
  end

  def test_sanitize__str
    s  = " hello world \xFE "
    s2 = Wgit::Utils.sanitize s
    expected = 'hello world �'

    assert_equal expected, s2
  end

  def test_sanitize__str__encode_false
    s  = ' hello world '
    s2 = Wgit::Utils.sanitize s, encode: false
    expected = 'hello world'

    assert_equal expected, s2

    s = " hello world \xFE "
    assert_raises(Encoding::CompatibilityError) { Wgit::Utils.sanitize(s, encode: false) }
  end

  def test_sanitize__str__url
    s  = Wgit::Url.new(' /about ')
    s2 = Wgit::Utils.sanitize s

    assert_equal '/about', s
    assert_instance_of Wgit::Url, s
    assert_equal '/about', s2
    assert_instance_of Wgit::Url, s2
  end

  def test_sanitize__arr
    a = ['', true, nil, true, false, ' hello world ', " hello world \xFE "]
    a2 = Wgit::Utils.sanitize a
    expected = [true, false, 'hello world', 'hello world �']

    assert_equal expected, a2
  end

  def test_sanitize__arr__encode_false
    a = ['', true, nil, true, false, ' hello world ']
    a2 = Wgit::Utils.sanitize a, encode: false
    expected = [true, false, 'hello world']

    assert_equal expected, a2

    a = ['', true, nil, true, false, ' hello world ', " hello world \xFE "]
    assert_raises(Encoding::CompatibilityError) { Wgit::Utils.sanitize(a, encode: false) }
  end

  def test_sanitize__arr__urls
    a = ['', true, nil, true, false, Wgit::Url.new(' /about ')]
    a2 = Wgit::Utils.sanitize a

    assert_equal [true, false, '/about'], a2
    assert_instance_of Wgit::Url, a2.last
  end

  def test_sanitize__random_type
    assert Wgit::Utils.sanitize(true)
  end

  def test_pprint
    buffer = StringIO.new
    Wgit::Utils.pprint(100, stream: buffer, name: 'michael', age: 34)
    assert_equal "\nDEBUG_100 - name: michael | age: 34\n\n", buffer.string
  end

  def test_pprint__new_line
    buffer = StringIO.new
    Wgit::Utils.pprint(1, stream: buffer, new_line: true, html: true, xml: false)

    expected = <<~TEXT

      DEBUG_1
      html: true
      xml: false

    TEXT
    assert_equal expected, buffer.string
  end

  private

  def printf_output__results
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
