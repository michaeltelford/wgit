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
    
    # Prints keys and values. Useful for debugging.
    def self.p_debug(debug_hash)
        debug_hash.each do |k, v|
            puts "#{k}: #{v}"
        end
        puts
        debug_hash.values
    end

    # Formats the sentence (modifies the receiver) and returns its value.
    # The length will be based on the sentence_limit parameter or the full
    # length of the original sentence, which ever is less. The algorithm
    # obviously ensures that the search value is visible somewhere in the
    # sentence.
    def self.format_sentence_length(sentence, index, sentence_limit)
        raise "A sentence value must be provided" if sentence.empty?
        raise "The sentence length value must be even" if sentence_limit.odd?
        if index < 0 or index > sentence.length
            raise "Incorrect index value"
        end

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

            if sentence[start..(finish - 1)].length != sentence_limit
                raise
            end
        end

        sentence.replace(sentence[start..(finish - 1)])
    end

    # Prints out the search results in a search engine page format.
    def self.printf_search_results(results, text = nil, case_sensitive = false,
                                   sentence_length = 80, keyword_count = 5)
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
            puts doc.title
            puts doc.keywords[0..keyword_count] unless doc.keywords.empty?
            puts sentence unless sentence.nil?
            puts doc.url
            puts
        end
        nil
    end
end
