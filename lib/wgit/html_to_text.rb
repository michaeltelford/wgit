require_relative 'utils'
require_relative 'assertable'
require 'nokogiri'

module Wgit
  # Class used to extract the visible page text from a HTML string.
  # This is used to set the output of a Wgit::Document#text method.
  class HtmlToText
    include Assertable

    # Set of text elements used to extract the visible text.
    # The element's display (:inline or :block) is used to delimit sentences.
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
      button:     :inline,
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
    end

    # Extracts and returns the text sentences from the @parser HTML.
    #
    # @return [Array<String>] An array of text sentences.
    def extract
      Utils.pprint "EXTRACT_TEXT_STARTING"

      return [] if @parser.to_s.empty?

      text_str = extract_text_str

      Utils.pprint "FINAL_TEXT_STR", text_str: text_str

      # Split the text_str into an Array of text sentences.
      text = text_str
        .squeeze("\n")
        .squeeze("\t")
        .split("\n")
        .reject { |t| t.strip.empty? }
        .uniq

      Utils.pprint "FINAL_TEXT", text: text

      text
    end

    private

    def extract_text_str
      text_str = ''

      iterate_child_nodes(@parser) do |node, display|

        Utils.pprint('NODE', node: node.name, text: node.text)

        # Skip any lines we don't care about.
        if node.text?
          # Only process text node if absent of new lines.
          next if node.text.include?("\n")
        else
          # Only process concrete node if it's only child is a text node.
          next unless node.children.size == 1 && has_text_node?(node)
        end

        add_new_line  = false
        prev          = prev_sibling_or_parent(node)
        prev_sib      = prev_sibling(node)

        if node.text?
          unless prev && inline?(prev)
            Utils.pprint 'ADDING_NEW_LINE_FOR_TEXT_1'
            add_new_line = true
          end
        else
          if prev && block?(prev) && !has_text_node?(prev)
            Utils.pprint 'ADDING_NEW_LINE_FOR_NODE_1'
            add_new_line = true
          end

          if prev_sib && display == :inline && block?(prev_sib)
            Utils.pprint 'ADDING_NEW_LINE_FOR_NODE_2'
            add_new_line = true
          end

          if prev_sib && display == :block && block?(prev_sib)
            Utils.pprint 'ADDING_NEW_LINE_FOR_NODE_3'
            add_new_line = true
          end
        end

        text_str << "\n" if add_new_line

        Utils.pprint 'ADDING_NODE_TEXT', node: node.name, text: node.text
        text_str << node.text
      end

      text_str
    end

    def node_name(node)
      node.name&.downcase&.to_sym
    end

    def display(node)
      name = node_name(node)
      HtmlToText.text_elements[name]
    end

    def inline?(node)
      display(node) == :inline
    end

    def block?(node)
      display(node) == :block
    end

    def prev_sibling(node)
      prev = node.previous
      return nil unless prev
      return prev unless prev.text?

      prev.previous
    end

    def prev_sibling_or_parent(node)
      prev = prev_sibling(node)
      return prev if prev

      node.parent
    end

    # Return true if any of its child nodes contain a non empty :text node.
    def has_text_node?(node)
      node.children.any? { |child| child.text? && !child.text.strip.empty? }
    end

    # Iterate over node and it's child nodes, yielding each to &block.
    # Only HtmlToText.text_elements or :text nodes will be yielded.
    # Duplicate text nodes (that follow a concrete node) are omitted.
    def iterate_child_nodes(node, &block)
      display = display(node)
      text_node = node.text? && node.text != node.parent.text

      yield(node, display) if display || text_node
      node.children.each { |child| iterate_child_nodes(child, &block) }
    end
  end
end
