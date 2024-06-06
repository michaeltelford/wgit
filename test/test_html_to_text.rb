require_relative 'helpers/test_helper'

# Test class for utility module functions.
class TestUtils < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup
    @use_cases = [
      # inline parent
      '<inline_parent><inline>*</inline></inline_parent>',
      '<inline_parent><inline>*</block></inline_parent>',
      '<inline_parent><block>*</inline></inline_parent>',
      '<inline_parent><block>*</block></inline_parent>',

      # block parent
      '<block_parent><inline>*</inline></block_parent>',
      '<block_parent><inline>*</block></block_parent>',
      '<block_parent><block>*</inline></block_parent>',
      '<block_parent><block>*</block></block_parent>'
    ]

    @content_variations = [
      '',
      'foobar',
      'foo bar',
      ' foo bar  ',
      ' ',
      '    ',
      "\n",
      "  \n ",
      '<br>',
      '<hr>'
    ]

    # For each use_case * text_variation combo above, what do we expect.
    @expected = [
      # inline parent - inline inline
      "prepost",
      "prefoobarpost",
      "prefoo barpost",
      "pre foo bar  post",
      "pre post",
      "pre    post",
      "prepost",
      "prepost",
      "pre\npost",
      "pre\npost",

      # inline parent - inline block
      "pre\npost",
      "prefoobar\npost",
      "prefoo bar\npost",
      "pre foo bar  \npost",
      "pre \npost",
      "pre    \npost",
      "pre\npost",
      "pre\npost",
      "pre\npost",
      "pre\npost",

      # inline parent - block inline
      "pre\npost",
      "pre\nfoobarpost",
      "pre\nfoo barpost",
      "pre\n foo bar  post",
      "pre\n post",
      "pre\n    post",
      "pre\npost",
      "pre\npost",
      "pre\npost",
      "pre\npost",

      # inline parent - block block
      "pre\npost",
      "pre\nfoobar\npost",
      "pre\nfoo bar\npost",
      "pre\n foo bar  \npost",
      "pre\n \npost",
      "pre\n    \npost",
      "pre\npost",
      "pre\npost",
      "pre\npost",
      "pre\npost",

      #######

      # block parent - inline inline
      "prepost",
      "prefoobarpost",
      "prefoo barpost",
      "pre foo bar  post",
      "pre post",
      "pre    post",
      "prepost",
      "prepost",
      "pre\npost",
      "pre\npost",

      # block parent - inline block
      "pre\npost",
      "prefoobar\npost",
      "prefoo bar\npost",
      "pre foo bar  \npost",
      "pre \npost",
      "pre    \npost",
      "pre\npost",
      "pre\npost",
      "pre\npost",
      "pre\npost",

      # block parent - block inline
      "pre\npost",
      "pre\nfoobarpost",
      "pre\nfoo barpost",
      "pre\n foo bar  post",
      "pre\n post",
      "pre\n    post",
      "pre\npost",
      "pre\npost",
      "pre\npost",
      "pre\npost",

      # block parent - block block
      "pre\npost",
      "pre\nfoobar\npost",
      "pre\nfoo bar\npost",
      "pre\n foo bar  \npost",
      "pre\n \npost",
      "pre\n    \npost",
      "pre\npost",
      "pre\npost",
      "pre\npost",
      "pre\npost"
    ]
  end

  def test_extract_text_str
    unless (@use_cases.size * @content_variations.size) == @expected.size
      raise 'invalid @expected array'
    end

    should_fail = false
    i = 0

    @use_cases.each do |use_case|
      @content_variations.each do |content|
        nodes = use_case
                .gsub('<inline_parent>',  '<span>')
                .gsub('</inline_parent>', '</span>')
                .gsub('<block_parent>',   '<div>')
                .gsub('</block_parent>',  '</div>')
                .gsub('<inline>',         '<span>pre</span>')
                .gsub('</inline>',        '<span>post</span>')
                .gsub('<block>',          '<div>pre</div>')
                .gsub('</block>',         '<div>post</div>')
                .gsub('*',                content)
        parser = Nokogiri::HTML("<html><body>#{nodes}</body></html>")

        expected = @expected[i]
        actual = Wgit::HtmlToText.new(parser).send(:extract_text_str)

        i += 1
        has_passed = expected == actual
        next if has_passed

        Wgit::Utils.pprint(i, prefix: 'TEST_EXTRACT_TEXT_STR_CASE', new_line: true,
          use_case: use_case, content: content, nodes: nodes, expected: expected, actual: actual)

        # should_fail = true
        flunk 'test_extract_text_str failed, see logs above for info'
      end
    end

    # flunk 'test_extract_text_str failed, see logs above for info' if should_fail
  end

  def test_extract__anchors
    url = 'http://example.com'.to_url
    html = File.read './test/mock/fixtures/anchor_display.html'
    doc = Wgit::Document.new url, html

    assert_equal ['About', 'Foo Location Bar', 'Contact Contact2Contact3'], doc.text
  end

  def test_extract__spans
    url = 'http://example.com'.to_url
    html = File.read './test/mock/fixtures/span_display.html'
    doc = Wgit::Document.new url, html

    assert_equal [
      'Running the following Wgit code will programmatically configure your database:',
      "db = Wgit::Database.new '<connection_string>'"
    ], doc.text
  end

  def test_extract__divs
    url = 'http://example.com'.to_url
    html = File.read './test/mock/fixtures/div_display.html'
    doc = Wgit::Document.new url, html

    assert_equal %w[foo bar], doc.text
  end

  def test_extract__getting_started_wiki
    url = 'http://example.com'.to_url
    html = File.read './test/mock/fixtures/getting_started.html'
    doc = Wgit::Document.new url, html

    assert_equal %w[todo], doc.text
  end
end
