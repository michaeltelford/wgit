# frozen_string_literal: true

module Wgit
  # Utility module containing generic methods that don't belong to a Class.
  module Utils
    # Returns the current time stamp.
    #
    # @return [Time] The current time stamp.
    def self.time_stamp
      Time.new
    end

    # Returns a Hash created from obj's instance vars and values.
    #
    # @param obj [Object] The object to process.
    # @param ignore [Array<String>] Attributes to ignore e.g. [':@html'].
    # @param use_strings_as_keys [Boolean] Whether to use Strings or Symbols as
    #   keys.
    # @return [Hash] A Hash created from obj's instance vars and values.
    def self.to_h(obj, ignore: [], use_strings_as_keys: true)
      hash = {}

      obj.instance_variables.each do |var|
        next if ignore.include?(var.to_s)

        key = var.to_s[1..-1] # Remove the @ prefix.
        key = key.to_sym unless use_strings_as_keys
        hash[key] = obj.instance_variable_get(var)
      end

      hash
    end

    # An improved :each method which supports both singleton and Enumerable
    # objects (as opposed to just an Enumerable object).
    #
    # @yield [el] Gives each element (Object) of obj_or_objects if it's
    #   Enumerable, otherwise obj_or_objs itself is given.
    # @return [Object] The obj_or_objs parameter is returned.
    def self.each(obj_or_objs)
      if obj_or_objs.respond_to?(:each)
        obj_or_objs.each { |obj| yield(obj) }
      else
        yield(obj_or_objs)
      end

      obj_or_objs
    end

    # Formats the sentence (modifies the receiver) and returns its value.
    # The formatting is essentially to shorten the sentence and ensure that
    # the index is present somewhere in the sentence. Used for search query
    # results with the index of the matching query.
    #
    # @param sentence [String] The sentence to be formatted.
    # @param index [Integer] The first index of a word in sentence. This is
    #   usually a word in a search query.
    # @param sentence_limit [Integer] The max length of the formatted sentence
    #   being returned. The length will be decided by the sentence_limit
    #   parameter or the full length of the original sentence, which ever
    #   is less. The full sentence is returned if the sentence_limit is 0.
    # @return [String] The sentence once formatted.
    def self.format_sentence_length(sentence, index, sentence_limit)
      raise 'A sentence value must be provided' if sentence.empty?
      raise 'The sentence length value must be even' if sentence_limit.odd?
      if index.negative? || (index > sentence.length)
        raise "Incorrect index value: #{index}"
      end

      return sentence if sentence_limit.zero?

      start  = 0
      finish = sentence.length

      if sentence.length > sentence_limit
        start  = index - (sentence_limit / 2)
        finish = index + (sentence_limit / 2)

        if start.negative?
          diff = 0 - start
          if (finish + diff) > sentence.length
            finish = sentence.length
          else
            finish += diff
          end
          start = 0
        elsif finish > sentence.length
          diff = finish - sentence.length
          if (start - diff).negative?
            start = 0
          else
            start -= diff
          end
          finish = sentence.length
        end

        raise if sentence[start..(finish - 1)].length != sentence_limit
      end

      sentence.replace(sentence[start..(finish - 1)])
    end

    # Prints out the search results in a search engine like format.
    # The format for each result looks like:
    #
    # Title
    #
    # Keywords (if there are some)
    #
    # Text Snippet (formatted to show the searched for query, if provided)
    #
    # URL
    #
    # <empty_line_seperator>
    #
    # @param results [Array<Wgit::Document>] Array of Wgit::Document's which
    #   each have had #search!(query) called (to update it's @text with the
    #   the search results). The first @text sentence gets printed.
    # @param keyword_limit [Integer] The max amount of keywords to be
    #   outputted to the stream.
    # @param stream [#puts] Any object that respond_to?(:puts). It is used
    #   to output text somewhere e.g. a file or STDOUT.
    def self.printf_search_results(results, keyword_limit: 5, stream: STDOUT)
      raise 'stream must respond_to? :puts' unless stream.respond_to?(:puts)

      results.each do |doc|
        title    = (doc.title || '<no title>')
        keywords = doc.keywords&.take(keyword_limit)&.join(', ')
        sentence = doc.text.first
        url      = doc.url

        stream.puts title
        stream.puts keywords if keywords
        stream.puts sentence
        stream.puts url
        stream.puts
      end

      nil
    end

    # Processes a String to make it uniform. Strips any leading/trailing white
    # space and converts to UTF-8.
    #
    # @param str [String] The String to process. str is modified.
    # @return [String] The processed str is both modified and then returned.
    def self.process_str(str)
      if str.is_a?(String)
        str.encode!('UTF-8', 'UTF-8', invalid: :replace)
        str.strip!
      end

      str
    end

    # Processes an Array to make it uniform. Removes empty Strings and nils,
    # processes non empty Strings using Wgit::Utils.process_str and removes
    # duplicates.
    #
    # @param arr [Enumerable] The Array to process. arr is modified.
    # @return [Enumerable] The processed arr is both modified and then returned.
    def self.process_arr(arr)
      if arr.is_a?(Array)
        arr.map! { |str| process_str(str) }
        arr.reject! { |str| str.is_a?(String) ? str.empty? : false }
        arr.compact!
        arr.uniq!
      end

      arr
    end

    # Returns the model having removed non bson types (for use with MongoDB).
    #
    # @param model_hash [Hash] The model Hash to process.
    # @return [Hash] The model Hash with non bson types removed.
    def self.remove_non_bson_types(model_hash)
      model_hash.select { |_k, v| v.respond_to?(:bson_type) }
    end
  end
end
