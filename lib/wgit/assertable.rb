module Wgit

  # Module containing assert methods including type checking which can be used
  # for asserting the integrity of method definitions etc.
  module Assertable
    # Default type fail message.
    DEFAULT_TYPE_FAIL_MSG = "Expected: %s, Actual: %s".freeze
    # Wrong method message.
    WRONG_METHOD_MSG = "arr must be Enumerable, use a different method".freeze
    # Default duck fail message.
    DEFAULT_DUCK_FAIL_MSG = "%s doesn't respond_to? %s".freeze
    # Default required keys message.
    DEFAULT_REQUIRED_KEYS_MSG = "Some or all of the required keys are not present: %s".freeze
  
    # Tests if the obj is of a given type.
    #
    # @param obj [Object] The Object to test.
    # @param type_or_types [Type, Array<Type>] The type/types that obj must
    #     belong to or an exception is thrown.
    # @param msg [String] The raised RuntimeError message, if provided.
    # @return [Object] The given obj on successful assertion.
    def assert_types(obj, type_or_types, msg = nil)
      msg ||= DEFAULT_TYPE_FAIL_MSG % [type_or_types, obj.class]
      if type_or_types.respond_to?(:any?)
        match = type_or_types.any? { |type| obj.instance_of?(type) }
      else
        match = obj.instance_of?(type_or_types)
      end
      raise msg unless match
      obj
    end
  
    # Each object within arr must match one of the types listed in 
    # type_or_types or an exception is raised using msg, if provided.
    #
    # @param arr [Enumerable#each] Enumerable of objects to type check.
    # @param type_or_types [Type, Array<Type>] The allowed type(s).
    # @param msg [String] The raised RuntimeError message, if provided.
    # @return [Object] The given arr on successful assertion.
    def assert_arr_types(arr, type_or_types, msg = nil)
      raise WRONG_METHOD_MSG unless arr.respond_to?(:each)
      arr.each do |obj|
        assert_types(obj, type_or_types, msg)
      end
    end

    # The obj_or_objs must respond_to? all of the given methods or an 
    # Exception is raised using msg, if provided.
    #
    # @param obj_or_objs [Object, Enumerable#each] The objects to duck check.
    # @param methods [Array<Symbol>] The methods to :respond_to?.
    # @param msg [String] The raised RuntimeError message, if provided.
    # @return [Object] The given obj_or_objs on successful assertion.
    def assert_respond_to(obj_or_objs, methods, msg = nil)
      methods = [methods] unless methods.respond_to?(:all?)
      if obj_or_objs.respond_to?(:each)
        obj_or_objs.each do |obj|
          _assert_respond_to(obj, methods, msg)
        end
      else
        _assert_respond_to(obj_or_objs, methods, msg)
      end
      obj_or_objs
    end

    # The hash must include? the keys or a KeyError is raised.
    #
    # @param hash [Hash] The hash which should include the required keys.
    # @param keys [Array<String, Symbol>] The keys whose presence to assert.
    # @param msg [String] The raised KeyError message, if provided.
    # @return [Hash] The given hash on successful assertion.
    def assert_required_keys(hash, keys, msg = nil)
      msg ||= DEFAULT_REQUIRED_KEYS_MSG % [keys.join(', ')]
      all_present = keys.all? { |key| hash.keys.include? key }
      raise KeyError.new(msg) unless all_present
      hash
    end

  private
  
    # obj must respond_to? all methods or an exception is raised.
    def _assert_respond_to(obj, methods, msg = nil)
      raise "methods must respond_to? :all?" unless methods.respond_to?(:all?)
      msg ||= DEFAULT_DUCK_FAIL_MSG % ["#{obj.class} (#{obj})", methods]
      match = methods.all? { |method| obj.respond_to?(method) }
      raise msg unless match
      obj
    end
  
    alias :assert_type :assert_types
    alias :type :assert_types
    alias :types :assert_types
    alias :assert_arr_type :assert_arr_types
    alias :arr_type :assert_arr_types
    alias :arr_types :assert_arr_types
    alias :respond_to :assert_respond_to
  end
end
