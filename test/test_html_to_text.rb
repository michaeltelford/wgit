require_relative "helpers/test_helper"

# Test class for utility module functions.
class TestHTMLToText < TestHelper
  # Run non DB tests in parallel for speed.
  parallelize_me!

  # Runs before every test.
  def setup
    @use_cases = [
      # inline parent
      "<inline_parent><inline>*</inline></inline_parent>",
      "<inline_parent><inline>*</block></inline_parent>",
      "<inline_parent><block>*</inline></inline_parent>",
      "<inline_parent><block>*</block></inline_parent>",

      # block parent
      "<block_parent><inline>*</inline></block_parent>",
      "<block_parent><inline>*</block></block_parent>",
      "<block_parent><block>*</inline></block_parent>",
      "<block_parent><block>*</block></block_parent>"
    ]

    @content_variations = [
      "",
      "foobar",
      "foo bar",
      " foo bar  ",
      " ",
      "    ",
      "\n",
      "  \n ",
      " \n foo bar \n ",
      "<br>",
      "<hr>"
    ]

    # For each use_case * text_variation combo above, what do we expect.
    @expected = [
      # inline parent - inline inline
      "prepost",
      "prefoobarpost",
      "prefoo barpost",
      "pre foo bar post",
      "pre post",
      "pre post",
      "prepost",
      "pre post",
      "pre foo bar post",
      "pre\npost",
      "pre\npost",

      # inline parent - inline block
      "pre\npost",
      "prefoobar\npost",
      "prefoo bar\npost",
      "pre foo bar \npost",
      "pre \npost",
      "pre \npost",
      "pre\npost",
      "pre \npost",
      "pre foo bar \npost",
      "pre\npost",
      "pre\npost",

      # inline parent - block inline
      "pre\npost",
      "pre\nfoobarpost",
      "pre\nfoo barpost",
      "pre\n foo bar post",
      "pre\n post",
      "pre\n post",
      "pre\npost",
      "pre\n \npost",
      "pre\n foo bar post",
      "pre\npost",
      "pre\npost",

      # inline parent - block block
      "pre\npost",
      "pre\nfoobar\npost",
      "pre\nfoo bar\npost",
      "pre\n foo bar \npost",
      "pre\n \npost",
      "pre\n \npost",
      "pre\npost",
      "pre\n \npost",
      "pre\n foo bar \npost",
      "pre\npost",
      "pre\npost",

      #######

      # block parent - inline inline
      "prepost",
      "prefoobarpost",
      "prefoo barpost",
      "pre foo bar post",
      "pre post",
      "pre post",
      "prepost",
      "pre post",
      "pre foo bar post",
      "pre\npost",
      "pre\npost",

      # block parent - inline block
      "pre\npost",
      "prefoobar\npost",
      "prefoo bar\npost",
      "pre foo bar \npost",
      "pre \npost",
      "pre \npost",
      "pre\npost",
      "pre \npost",
      "pre foo bar \npost",
      "pre\npost",
      "pre\npost",

      # block parent - block inline
      "pre\npost",
      "pre\nfoobarpost",
      "pre\nfoo barpost",
      "pre\n foo bar post",
      "pre\n post",
      "pre\n post",
      "pre\npost",
      "pre\n \npost",
      "pre\n foo bar post",
      "pre\npost",
      "pre\npost",

      # block parent - block block
      "pre\npost",
      "pre\nfoobar\npost",
      "pre\nfoo bar\npost",
      "pre\n foo bar \npost",
      "pre\n \npost",
      "pre\n \npost",
      "pre\npost",
      "pre\n \npost",
      "pre\n foo bar \npost",
      "pre\npost",
      "pre\npost"
    ]
  end

  def test_extract_text_str
    total_test_cases = @use_cases.size * @content_variations.size
    should_fail = false
    fail_count = 0
    i = 0

    raise "invalid @expected array" unless total_test_cases == @expected.size

    @use_cases.each do |use_case|
      @content_variations.each do |content|
        nodes = gsub_use_case_content(use_case, content)
        parser = Nokogiri::HTML("<html><body>#{nodes}</body></html>")

        expected = @expected[i]
        actual = Wgit::HTMLToText.new(parser).extract_str

        i += 1
        assert true # Add our assertion to minitest's total.
        has_passed = expected == actual
        next if has_passed

        Wgit::Utils.pprint("CASE_#{i}", prefix: "TEST_EXTRACT_TEXT_STR", new_line: true,
          use_case: use_case, content: content, nodes: nodes, expected: expected, actual: actual)

        should_fail = true
        fail_count += 1
      end
    end

    return unless should_fail

    Wgit::Utils.pprint("SUMMARY", prefix: "TEST_EXTRACT_TEXT_STR", new_line: true,
      total_test_cases: total_test_cases, total_failing_cases: fail_count)

    flunk "test_extract_text_str failed, see logs above for info"
  end

  def test_extract__anchors
    url = "http://example.com".to_url
    html = File.read "./test/mock/fixtures/anchor_display.html"
    doc = Wgit::Document.new url, html

    assert_equal ["About", "Foo Location Bar", "Contact Contact2 Contact3"], doc.text
  end

  def test_extract__spans
    url = "http://example.com".to_url
    html = File.read "./test/mock/fixtures/span_display.html"
    doc = Wgit::Document.new url, html

    assert_equal [
      "Running the following Wgit code will programmatically configure your database:",
      "db = Wgit::Database.new '<connection_string>'"
    ], doc.text
  end

  def test_extract__divs
    url = "http://example.com".to_url
    html = File.read "./test/mock/fixtures/div_display.html"
    doc = Wgit::Document.new url, html

    assert_equal %w[foo bar], doc.text
  end

  def test_extract__getting_started_wiki
    url = "http://example.com".to_url
    html = File.read "./test/mock/fixtures/getting_started.html"
    doc = Wgit::Document.new url, html

    assert_equal [
      "Running the following Wgit code will programmatically configure your database:",
      "db = Wgit::Database.new '<connection_string>'",
      "db.create_collections",
      "db.create_unique_indexes",
      "db.text_index = Wgit::Database::DEFAULT_TEXT_INDEX",
      "Or take a look at the mongo_init.js file for the equivalent Javascript commands.",
      "Note: The text search index lists all document fields to be searched by MongoDB when calling Wgit::Database#search. Therefore, you should append this list with any other fields that you want searched. For example, if you extend the API then you might want to search your new fields in the database by adding them to the index above. This can be done programmatically with:"
    ], doc.text
  end

  def test_extract__dups_are_not_removed
    doc = Wgit::Document.new "http://www.mytestsite.com/home", <<~HTML
      <p>Note: The text search index lists all document fields.</p>
      <hr>
      <p>Note: The text search index lists all document fields.</p>
    HTML

    assert_equal [
      "Note: The text search index lists all document fields.",
      "Note: The text search index lists all document fields."
    ], doc.text
  end

  private

  def gsub_use_case_content(use_case, content)
    use_case
      .gsub("<inline_parent>",  "<span>")
      .gsub("</inline_parent>", "</span>")
      .gsub("<block_parent>",   "<div>")
      .gsub("</block_parent>",  "</div>")
      .gsub("<inline>",         "<span>pre</span>")
      .gsub("</inline>",        "<span>post</span>")
      .gsub("<block>",          "<div>pre</div>")
      .gsub("</block>",         "<div>post</div>")
      .gsub("*",                content)
  end
end
