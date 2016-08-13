
module Wgit

  # @author Michael Telford
  # Utility module containing generic methods.
  module Utils
      def self.time_stamp
          Time.new
      end

      # Returns a hash created from obj's instance vars and values.
      def self.to_h(obj, ignore = [])
          hash = {}
          obj.instance_variables.each do |var|
              next if ignore.include?(var)
              hash[var[1..-1].to_sym] = obj.instance_variable_get(var)
          end
          hash
      end

      # Improved each method which takes care of singleton and enumerable
      # objects. Yields one or more objects.
      def self.each(obj_or_objs)
          if obj_or_objs.respond_to?(:each)
              obj_or_objs.each { |obj| yield obj }
          else
              yield obj_or_objs
          end
      end

      # Formats the sentence (modifies the receiver) and returns its value.
      # The length will be based on the sentence_limit parameter or the full
      # length of the original sentence, which ever is less. The full sentence
      # is returned if the sentence_limit is 0. The algorithm obviously ensures 
      # that the search value is visible somewhere in the sentence.
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

      # Prints out the search results in a search engine page format.
      # Most of the params are passed to Document#search - see class docs. 
      # The steam param decides where the printf output is written to, and 
      # therefore must respond_to? :puts
      # The format for each result is:
      #
      # Title
      # Keywords (if there are some)
      # Text Snippet (showing the searched for text if provided)
      # Url
      # <empty_line>
      def self.printf_search_results(results, text = nil, case_sensitive = false,
                                     sentence_length = 80, keyword_count = 5, 
                                     stream = Kernel)
          raise "stream must respond_to? :puts" unless stream.respond_to? :puts
          keyword_count -= 1 # Because Array's are zero indexed.
        
          results.each do |doc|
              sentence = if text.nil?
                            nil
                         else
                            sentence = doc.search(text, sentence_length).first
                            if sentence.nil?
                                nil
                            else
                                sentence.strip.empty? ? nil : sentence
                            end
                         end
              stream.puts doc.title
              unless doc.keywords.empty?
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
