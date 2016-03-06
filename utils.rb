# @author Michael Telford
# Utility module containing generic methods.
module Utils
    def self.time_stamp
        Time.new
    end
    
    def self.to_h(obj, ignore = [])
        hash = {}
        obj.instance_variables.each do |var|
            next if ignore.include?(var)
            hash[var[1..-1]] = obj.instance_variable_get(var)
        end
        hash
    end
    
    # obj_or_objs will have its type or its elements types (if it's an 
    # Enumerator) checked and return true if the type matches type_or_types or 
    # one of its listed types if it's an Enumerator).
    # 
    # Therefore if you want to check for an array use: 
    # Utils.assert_type [arr], Array
    # The arr elements will not be checked because arr is inside an array.
    # Likewise to check for a String use:
    # Utils.assert_type [str], String
    # 
    # To check for a Url or Array containing only Urls use: 
    # Utils.assert_type url_or_urls, Url
    # arr will not have its type checked because its an Array, only its 
    # elements, each of which must be a Url.
    # 
    # If there isn't a match then an exception is thrown. The exception 
    # message is msg if provided or the default one.
    def self.assert_type(obj_or_objs, type_or_types, msg = nil)
        if obj_or_objs.is_a?(Array)
            obj_or_objs.each do |obj|
                _assert_type(obj, type_or_types, msg)
            end
        else
            _assert_type(obj_or_objs, type_or_types, msg)
        end
        obj_or_objs
    end

    def self._assert_type(obj, type_or_types, msg = nil)
        if type_or_types.respond_to?(:each)
            match = false
            type_or_types.each do |type|
                if obj.is_a?(type)
                    match = true
                    break
                end
            end
            unless match
                if msg.nil?
                    raise "Expecting: #{type_or_types}, Got: #{obj.class}"
                else
                    raise msg
                end
            end
        else
            type = type_or_types
            unless obj.is_a?(type)
                if (msg.nil?)
                    raise "Expecting: #{type}, Got: #{obj.class}"
                else
                    raise msg
                end
            end
        end
        obj
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
                                                case_sensitive, 
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
    
    private_class_method :_assert_type
end
