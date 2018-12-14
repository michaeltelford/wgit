module Wgit

  # Utility module containing generic methods.
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
      # @param ignore [Array<String>] Attributes to ignore.
      # @param use_strings_as_keys [Boolean] Whether or not to use strings as
      #     the keys in the returned Hash. Symbols are used otherwise.
      # @return [Hash] A Hash created from obj's instance vars and values.
      def self.to_h(obj, ignore = [], use_strings_as_keys = true)
          hash = {}
          obj.instance_variables.each do |var|
              next if ignore.include?(var.to_s)
              key = var.to_s[1..-1]
              key = key.to_sym unless use_strings_as_keys
              hash[key] = obj.instance_variable_get(var)
          end
          hash
      end
      
      # Returns the model having removed non bson types (for use with MongoDB).
      #
      # @param model_hash [Hash] The model Hash to process.
      # @return [Hash] The model Hash with non bson types removed.
      def self.remove_non_bson_types(model_hash)
        model_hash.reject do |k, v|
          not v.respond_to? :bson_type
        end
      end

      # An improved :each method which accepts both singleton and Enumerable
      # objects (as opposed to just an Enumerable object).
      #
      # @yield [el] Gives each element of obj_or_objects if it's Enumerable,
      #     otherwise obj_or_objs itself is given.
      def self.each(obj_or_objs)
          if obj_or_objs.respond_to?(:each)
              obj_or_objs.each { |obj| yield obj }
          else
              yield obj_or_objs
          end
      end

      # Formats the sentence (modifies the receiver) and returns its value.
      # The formatting is essentially to shorten the sentence and ensure that
      # the index is present somewhere in the sentence. Used for search query
      # results.
      #
      # @param sentence [String] The sentence to be formatted.
      # @param index [Integer] The first index of a word in sentence. This is
      #     usually a word in a search query.
      # @param sentence_limit [Integer] The max length of the formatted sentence
      #     being returned. The length will be based on the sentence_limit 
      #     parameter or the full length of the original sentence, which ever
      #     is less. The full sentence is returned if the sentence_limit is 0.
      # @return [String] The sentence once formatted.
      def self.format_sentence_length(sentence, index, sentence_limit)
          raise "A sentence value must be provided" if sentence.empty?
          raise "The sentence length value must be even" if sentence_limit.odd?
          if index < 0 or index > sentence.length
              raise "Incorrect index value: #{index}"
          end
        
          return sentence if sentence_limit == 0

          start = 0
          finish = sentence.length

          if sentence.length > sentence_limit
              start = index - (sentence_limit / 2)
              finish = index + (sentence_limit / 2)

              if start < 0
                  diff = 0 - start
                  if (finish + diff) > sentence.length
                      finish = sentence.length
                  else
                      finish += diff
                  end
                  start = 0
              elsif finish > sentence.length
                  diff = finish - sentence.length
                  if (start - diff) < 0
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
      # Most of the params are passed to Wgit::Document#search; see the docs.
      # The format for each result looks like:
      #
      # Title
      #
      # Keywords (if there are some)
      #
      # Text Snippet (showing the searched for query if provided)
      #
      # URL
      #
      # <empty_line_seperator>
      #
      # @param results [Array<Wgit::Document>] An Array whose
      #     Wgit::Documents#text matches the query at least once.
      # @param query [String] The text query to search for.
      # @param case_sensitive [Boolean] Whether or not the search should be
      #     case sensitive or not.
      # @param sentence_length [Integer] The length of the matching text of the
      #     search results to be outputted to the stream.
      # @param keyword_count [Integer] The max amount of keywords to be
      #     outputted to the stream.
      # @param stream [#puts] Any object that respond_to? :puts. It is used
      #     to output text somewhere e.g. STDOUT (the default).
      # @return [nil]
      def self.printf_search_results(results, query = nil, case_sensitive = false,
                                     sentence_length = 80, keyword_count = 5, 
                                     stream = Kernel)
          raise "stream must respond_to? :puts" unless stream.respond_to? :puts
          keyword_count -= 1 # Because Array's are zero indexed.
        
          results.each do |doc|
              sentence = if query.nil?
                            nil
                         else
                            sentence = doc.search(query, sentence_length).first
                            if sentence.nil?
                                nil
                            else
                                sentence.strip.empty? ? nil : sentence
                            end
                         end
              stream.puts doc.title
              unless doc.keywords.nil? || doc.keywords.empty?
                  stream.puts doc.keywords[0..keyword_count].join(", ")
              end
              stream.puts sentence unless sentence.nil?
              stream.puts doc.url
              stream.puts
          end
          
          nil
      end
  end
end
