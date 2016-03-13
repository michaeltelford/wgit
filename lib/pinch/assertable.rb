# @author Michael Telford
# Module containing assert methods including type checking which can be used 
# for asserting the integrity of method definitions etc. 
module Assertable
    DEFAULT_FAIL_MSG = "Expected: %s, Actual: %s"
    WRONG_METHOD_MSG = 
        "arr must be Enumerable, use Assertable#assert_type for obj's"
    
    # obj.instance_of? must return true for one of the types listed in 
    # type_or_types or an exception is thrown using msg if provided. 
    # type_or_types can be a single Class or an Enumerable of Class objects, 
    # Strings and Symbols will not work. 
    def assert_type(obj, type_or_types, msg = nil)
        msg ||= DEFAULT_FAIL_MSG % [type_or_types, obj.class]
        if type_or_types.respond_to?(:any?)
            match = type_or_types.any? { |type| obj.instance_of?(type) }
        else
            match = obj.instance_of?(type_or_types)
        end
        raise msg unless match
        obj
    end
    
    # Each object within arr must match one of the types listed in 
    # type_or_types or an exception is thrown using msg if provided. 
    # type_or_types can be a single Class or an Enumerable of Class objects, 
    # Strings and Symbols will not work. 
    def assert_arr_types(arr, type_or_types, msg = nil)
        raise WRONG_METHOD_MSG unless arr.respond_to?(:each)
        arr.each do |obj|
            assert_type(obj, type_or_types, msg)
        end
    end
    
    alias :type :assert_type
    alias :arr_types :assert_arr_types
end
