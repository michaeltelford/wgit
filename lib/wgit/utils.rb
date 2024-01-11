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

        key = var.to_s[1..] # Remove the @ prefix.
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
    def self.each(obj_or_objs, &block)
      if obj_or_objs.respond_to?(:each)
        obj_or_objs.each(&block)
      else
        yield(obj_or_objs)
      end

      obj_or_objs
    end

    # An improved Hash :fetch method which checks for multiple formats of the
    # given key and returns the value, or the default value (nil unless
    # provided).
    #
    # For example, if key == :foo, hash is searched for:
    # :foo, 'foo', 'Foo', 'FOO' in that order. The first value found is
    # returned. If no value is found, the default value is returned.
    #
    # @param hash [Hash] The Hash to search within.
    # @param key [Symbol, String] The key with which to search hash.
    # @param default [Object] The default value to be returned if hash[key]
    #   doesn't exist.
    # @return [Object] The value found at hash[key] or the default value.
    def self.fetch(hash, key, default = nil)
      key = key.to_s.downcase

      # Try (in order): :foo, 'foo', 'Foo', 'FOO'.
      [key.to_sym, key, key.capitalize, key.upcase].each do |k|
        value = hash[k]

        return value if value
      end

      default
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
    # ```
    # Title
    # Keywords (if there are some)
    # Text Snippet (formatted to show the searched for query, if provided)
    # URL
    # <empty_line_seperator>
    # ```
    #
    # @param results [Array<Wgit::Document>] Array of Wgit::Document's which
    #   each have had #search!(query) called (to update it's @text with the
    #   the search results). The first @text sentence gets printed.
    # @param keyword_limit [Integer] The max amount of keywords to be
    #   outputted to the stream.
    # @param stream [#puts] Any object that respond_to?(:puts). It is used
    #   to output text somewhere e.g. a file or STDERR.
    # @return [Integer] The number of results.
    def self.pprint_search_results(results, keyword_limit: 5, stream: $stdout)
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

      results.size
    end

    # Sanitises the obj to make it uniform by calling the correct sanitize_*
    # method for its type e.g. if obj.is_a? String then sanitize_str(obj) is called.
    # Any type not in the case statement will be ignored and returned as is.
    # Call this method if unsure what obj's type is.
    #
    # @param obj [Object] The object to be sanitized.
    # @param encode [Boolean] Whether or not to encode to UTF-8 replacing
    #   invalid characters.
    # @return [Object] The sanitized obj.
    def self.sanitize(obj, encode: true)
      case obj
      when Wgit::Url
        sanitize_url(obj, encode:)
      when String
        sanitize_str(obj, encode:)
      when Array
        sanitize_arr(obj, encode:)
      else
        obj
      end
    end

    # Sanitises a Wgit::Url to make it uniform. First sanitizes the Url as a
    # String before replacing the Url value with the sanitized version. This
    # method therefore modifies the given url param and also returns it.
    #
    # @param url [Wgit::Url] The Wgit::Url to sanitize. url is modified.
    # @param encode [Boolean] Whether or not to encode to UTF-8 replacing
    #   invalid characters.
    # @return [Wgit::Url] The sanitized url, which is also modified.
    def self.sanitize_url(url, encode: true)
      str = sanitize_str(url.to_s, encode:)
      url.replace(str)
    end

    # Sanitises a String to make it uniform. Strips any leading/trailing white
    # space. Also applies UTF-8 encoding (replacing invalid characters) if
    # `encode: true`.
    #
    # @param str [String] The String to sanitize. str is not modified.
    # @param encode [Boolean] Whether or not to encode to UTF-8 replacing
    #   invalid characters.
    # @return [String] The sanitized str.
    def self.sanitize_str(str, encode: true)
      return str unless str.is_a?(String)

      str = str.encode('UTF-8', undef: :replace, invalid: :replace) if encode
      str.strip
    end

    # Sanitises an Array to make it uniform. Removes empty Strings and nils,
    # processes non empty Strings using Wgit::Utils.sanitize and removes
    # duplicates.
    #
    # @param arr [Enumerable] The Array to sanitize. arr is not modified.
    # @return [Enumerable] The sanitized arr.
    def self.sanitize_arr(arr, encode: true)
      return arr unless arr.is_a?(Array)

      arr
        .map { |str| sanitize(str, encode:) }
        .reject { |str| str.is_a?(String) && str.empty? }
        .compact
        .uniq
    end

    # Pretty prints a log statement, used for debugging purposes.
    #
    # Use like:
    #
    # ```
    # Wgit::Utils.pprint 1, include_html: include_html, ignore: ignore_vars
    # ```
    #
    # Which produces a log like:
    #
    # ```
    # DEBUG_1 - include_html: true | ignore: ['@html', '@parser']
    # ```
    #
    # @param identifier [#to_s] A log identifier e.g. "START" or 1 etc.
    # @param stream [#puts] Any object that respond_to? :puts and :print. It is
    #   used to output the log text somewhere e.g. a file or STDERR.
    # @param prefix [String] The log prefix, useful for visibility/greping.
    # @param new_line [Boolean] Wether or not to use a new line (\n) as the
    #   separator.
    # @param vars [Hash<#inspect, #inspect>] The vars to inspect in the log.
    def self.pprint(identifier, stream: $stdout, prefix: 'DEBUG', new_line: false, **vars)
      sep1 = new_line ? "\n" : ' - '
      sep2 = new_line ? "\n" : ' | '

      stream.print "\n#{prefix}_#{identifier}#{sep1}"

      vars.each_with_index do |arr, i|
        last_item = (i + 1) == vars.size
        sep3 = sep2
        sep3 = new_line ? "\n" : '' if last_item
        k, v = arr

        stream.print "#{k}: #{v}#{sep3}"
      end

      stream.puts "\n"
      stream.puts "\n" unless new_line

      nil
    end
  end
end
