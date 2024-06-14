require_relative "utils"
require_relative "assertable"
require "nokogiri"

module Wgit
  # Class used to extract the visible page text from a HTML string.
  # This is in turn used to set the output of a Wgit::Document#text method.
  class HTMLToText
    include Assertable

    # Set of text elements used to extract the visible text.
    # The element's display (:inline or :block) is used to delimit sentences e.g.
    # <div>foo</div><div>bar</div> will be extracted as ['foo', 'bar'] whereas
    # <span>foo</span><span>bar</span> will be extracted as ['foobar'].
    @text_elements = {
      a:          :inline,
      abbr:       :inline,
      address:    :block,
      article:    :block,
      aside:      :block,
      b:          :inline,
      bdi:        :inline,
      bdo:        :inline,
      blockquote: :block,
      br:         :block,
      button:     :block, # Normally inline but Wgit treats as block.
      caption:    :block,
      cite:       :inline,
      code:       :inline,
      data:       :inline,
      dd:         :block,
      del:        :inline,
      details:    :block,
      dfn:        :inline,
      div:        :block,
      dl:         :block,
      dt:         :block,
      em:         :inline,
      figcaption: :block,
      figure:     :block,
      footer:     :block,
      h1:         :block,
      h2:         :block,
      h3:         :block,
      h4:         :block,
      h5:         :block,
      h6:         :block,
      header:     :block,
      hr:         :block,
      i:          :inline,
      input:      :inline,
      ins:        :block,
      kbd:        :inline,
      label:      :inline,
      legend:     :block,
      li:         :block,
      main:       :block,
      mark:       :inline,
      meter:      :block,
      ol:         :block,
      option:     :block,
      output:     :block,
      p:          :block,
      pre:        :block,
      q:          :inline,
      rb:         :inline,
      rt:         :inline,
      ruby:       :inline,
      s:          :inline,
      samp:       :inline,
      section:    :block,
      small:      :inline,
      span:       :inline,
      strong:     :inline,
      sub:        :inline,
      summary:    :block,
      sup:        :inline,
      td:         :block,
      textarea:   :block,
      th:         :block,
      time:       :inline,
      u:          :inline,
      ul:         :block,
      var:        :inline,
      wbr:        :inline
    }

    class << self
      # Set of HTML elements that make up the visible text on a page. These
      # elements are used to initialize the Wgit::Document#text. See the
      # README.md for how to add to this Hash dynamically.
      attr_reader :text_elements
    end

    # The Nokogiri::HTML document object initialized from a HTML string.
    attr_reader :parser

    # Creates a new HTML to text extractor instance.
    #
    # @param parser [Nokogiri::HTML4::Document] The nokogiri parser object.
    # @raise [StandardError] If the given parser is of an invalid type.
    def initialize(parser)
      assert_type(parser, Nokogiri::HTML4::Document)

      @parser = parser
      @display_logs = ENV["WGIT_DEBUG_HTML_TO_TEXT"]
    end

    # Extracts and returns the text sentences from the @parser HTML.
    #
    # @return [Array<String>] An array of unique text sentences.
    def extract_arr
      Wgit::Utils.pprint("START_TEXT_ARR", display: @display_logs)

      return [] if @parser.to_s.empty?

      text_str = extract_str

      Wgit::Utils.pprint("FINAL_TEXT_STR", display: @display_logs,
text_str: text_str)

      # Split the text_str into an Array of text sentences.
      text = text_str
             .split("\n")
             .map(&:strip)
             .reject(&:empty?)
             .uniq

      Wgit::Utils.pprint("FINAL_TEXT_ARR", display: @display_logs, text: text)

      text
    end

    # Extracts and returns a text string from the @parser HTML.
    #
    # @return [String] A string of text with \n delimiting sentences.
    def extract_str
      text_str = ""

      iterate_child_nodes(@parser) do |node, display|
        Wgit::Utils.pprint("NODE", display: @display_logs, node: node.name,
text: node.text)

        # byebug if node_name(node) == :span && node.text.downcase == 'post'

        # Handle any special cases e.g. skip nodes we don't care about...
        # <pre> nodes should have their contents displayed exactly as is.
        if node_name(node) == :pre
          Wgit::Utils.pprint("ADDING_PRE_CONTENT_AS_IS", display: @display_logs,
content: "\n#{node.text}")

          text_str << "\n"
          text_str << node.text
          next
        end

        # Skip any child node of <pre> since they're handled as a special case above.
        next if child_of?(:pre, node)

        if node.text?
          # Skip any text element that is purely whitespace.
          next unless valid_text_content?(node.text)
        else
          # Skip a concrete node if it has other concrete child nodes as these
          # will be iterated onto later.
          #
          # Process if node has no children or one child which is a valid text node.
          unless node.children.empty? || (node.children.size == 1 && parent_of_text_node?(node))
            next
          end
        end

        # Apply display rules deciding if a new line is needed before node.text.
        add_new_line = false
        node_text    = format_text(node.text)
        prev         = prev_sibling_or_parent(node)

        if node.text?
          unless prev && inline?(prev)
            Wgit::Utils.pprint("ADDING_NEW_LINE_FOR_TEXT_1", display: @display_logs)
            add_new_line = true
          end
        else
          if display == :block
            Wgit::Utils.pprint("ADDING_NEW_LINE_FOR_NODE_1", display: @display_logs)
            add_new_line = true
          end

          if prev && block?(prev)
            Wgit::Utils.pprint("ADDING_NEW_LINE_FOR_NODE_2", display: @display_logs)
            add_new_line = true
          end
        end

        text_str << "\n" if add_new_line

        Wgit::Utils.pprint("ADDING_NODE_TEXT", display: @display_logs,
node: node.name, text: node_text)
        text_str << node_text
      end

      Wgit::Utils.pprint("TEXT_STR_PRE_SQUEEZE", display: @display_logs,
text_str: text_str)

      text_str
        .strip
        .squeeze("\n")
        .squeeze(" ")
    end

    private

    def node_name(node)
      node.name&.downcase&.to_sym
    end

    def display(node)
      name = node_name(node)
      Wgit::HTMLToText.text_elements[name]
    end

    def inline?(node)
      display(node) == :inline
    end

    def block?(node)
      display(node) == :block
    end

    # Returns the previous sibling of node or nil. Only valid text elements are
    # returned i.e. non duplicates with valid text content.
    def prev_sibling(node)
      prev = node.previous

      return nil unless prev
      return prev unless prev.text?
      return prev if valid_text_node?(prev) && !contains_new_line?(prev.text)
      return prev if valid_text_node?(prev) && !format_text(prev.text).strip.empty?

      prev.previous
    end

    # Returns node's previous sibling, parent or nil; in that order. Only valid
    # text elements are returned i.e. non duplicates with valid text content.
    def prev_sibling_or_parent(node)
      prev = prev_sibling(node)
      return prev if prev

      node.parent
    end

    def child_of?(ancestor_name, node)
      node.ancestors.any? { |ancestor| node_name(ancestor) == ancestor_name }
    end

    # Returns true if any of the child nodes contain a non empty :text node.
    def parent_of_text_node?(node)
      node.children.any? { |child| child.text? && valid_text_content?(child.text) }
    end

    # Returns true if text is not empty having removed all new lines.
    def valid_text_content?(text)
      !format_text(text).empty?
    end

    # Returns true if node is a text node.
    # Duplicate text nodes (that follow a concrete node) are omitted.
    def valid_text_node?(node)
      node.text? && node.text != node.parent.text
    end

    def contains_new_line?(text)
      ["\n", '\\n'].any? { |new_line| text.include?(new_line) }
    end

    # Remove special characters including any new lines; as semantic HTML will
    # typically use <br> and/or block elements to denote a line break.
    def format_text(text)
      text
        .encode("UTF-8", undef: :replace, invalid: :replace)
        .gsub("\n",       "")
        .gsub('\\n',      "")
        .gsub("\r",       "")
        .gsub('\\r',      "")
        .gsub("\f",       "")
        .gsub('\\f',      "")
        .gsub("\t",       "")
        .gsub('\\t',      "")
        .gsub("&zwnj;",   "")
        .gsub("&nbsp;",   " ")
        .gsub("&#160;",   " ")
        .gsub("&thinsp;", " ")
        .gsub("&ensp;",   " ")
        .gsub("&emsp;",   " ")
        .gsub('\u00a0',   " ")
    end

    # Iterate over node and it's child nodes, yielding each to &block.
    # Only HTMLToText.text_elements or valid :text nodes will be yielded.
    # Duplicate text nodes (that follow a concrete node) are omitted.
    def iterate_child_nodes(node, &block)
      display = display(node)
      text_node = valid_text_node?(node)

      yield(node, display) if display || text_node
      node.children.each { |child| iterate_child_nodes(child, &block) }
    end

    alias_method :extract, :extract_arr
  end
end
