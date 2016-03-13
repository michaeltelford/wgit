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
            hash[var[1..-1]] = obj.instance_variable_get(var)
        end
        hash
    end
    
    # Prints out the search results in a search engine page format.
    def self.printf_search_results(results, text = nil, case_sensitive = false,
                                   sentence_length = 80, keyword_count = 5)
        keyword_count -= 1 # Because Array's are zero indexed.
        results.each do |doc|
            sentence = if text.nil?
                          nil
                       else
                          sentence = doc.search(text, 
                                                sentence_length).first
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
