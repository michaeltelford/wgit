# frozen_string_literal: true

module Wgit
  # Module containing assertion methods including type checking and duck typing.
  module Assertable
    # Default type fail message.
    DEFAULT_TYPE_FAIL_MSG = 'Expected: %s, Actual: %s'

    # Wrong method message.
    NON_ENUMERABLE_MSG = 'Expected an Enumerable responding to #each, not: %s'

    # Enumerable with more than one type across it's elements.
    MIXED_ENUMERABLE_MSG = "Expected an Enumerable with elements of a single \
common type"

    # Default duck fail message.
    DEFAULT_DUCK_FAIL_MSG = "%s doesn't respond_to? %s"

    # Default required keys message.
    DEFAULT_REQUIRED_KEYS_MSG = "Some or all of the required keys are not \
present: %s"

    # Tests if the obj is_a? given type; raises an Exception if not.
    #
    # @param obj [Object] The Object to test.
    # @param type_or_types [Type, Array<Type>] The type/types that obj must
    #     belong to or an exception is thrown.
    # @param msg [String] The raised StandardError message, if provided.
    # @raise [StandardError] If the assertion fails.
    # @return [Object] The given obj on successful assertion.
    def assert_types(obj, type_or_types, msg = nil)
      msg ||= format(DEFAULT_TYPE_FAIL_MSG, type_or_types, obj.class)
      match = if type_or_types.respond_to?(:any?)
                type_or_types.any? { |type| obj.is_a?(type) }
              else
                obj.is_a?(type_or_types)
              end
      raise msg unless match

      obj
    end

    # Each object within arr must match one of the types listed in
    # type_or_types; or an exception is raised using msg, if provided.
    #
    # @param arr [Enumerable#each] Enumerable of objects to type check.
    # @param type_or_types [Type, Array<Type>] The allowed type(s).
    # @param msg [String] The raised StandardError message, if provided.
    # @raise [StandardError] If the assertion fails.
    # @return [Object] The given arr on successful assertion.
    def assert_arr_types(arr, type_or_types, msg = nil)
      raise format(NON_ENUMERABLE_MSG, arr.class) unless arr.respond_to?(:each)

      arr.each { |obj| assert_types(obj, type_or_types, msg) }
    end

    # All objects within arr must match one of the types listed in
    # type_or_types; or an exception is raised using msg, if provided.
    # Ancestors of the same type are allowed and considered common.
    #
    # @param arr [Enumerable#each] Enumerable of objects to type check.
    # @param type_or_types [Type, Array<Type>] The allowed type(s).
    # @param msg [String] The raised StandardError message, if provided.
    # @raise [StandardError] If the assertion fails.
    # @return [Object] The given arr on successful assertion.
    def assert_common_arr_types(arr, type_or_types, msg = nil)
      raise format(NON_ENUMERABLE_MSG, arr.class) unless arr.respond_to?(:each)

      type = arr.first.class
      type_match = arr.all? { |obj| type.ancestors.include?(obj.class) }
      raise MIXED_ENUMERABLE_MSG unless type_match

      assert_arr_types(arr, type_or_types, msg)
    end

    # The obj_or_objs must respond_to? all of the given methods or an
    # Exception is raised using msg, if provided.
    #
    # @param obj_or_objs [Object, Enumerable#each] The object(s) to duck check.
    # @param methods [Array<Symbol>] The methods to :respond_to?.
    # @param msg [String] The raised StandardError message, if provided.
    # @raise [StandardError] If the assertion fails.
    # @return [Object] The given obj_or_objs on successful assertion.
    def assert_respond_to(obj_or_objs, methods, msg = nil)
      methods = *methods

      if obj_or_objs.respond_to?(:each)
        obj_or_objs.each { |obj| _assert_respond_to(obj, methods, msg) }
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
    # @raise [KeyError] If the assertion fails.
    # @return [Hash] The given hash on successful assertion.
    def assert_required_keys(hash, keys, msg = nil)
      msg ||= format(DEFAULT_REQUIRED_KEYS_MSG, keys.join(', '))
      all_present = keys.all? { |key| hash.keys.include? key }
      raise KeyError, msg unless all_present

      hash
    end

    private

    # obj must respond_to? all methods or an exception is raised.
    def _assert_respond_to(obj, methods, msg = nil)
      raise 'methods must respond_to? :all?' unless methods.respond_to?(:all?)

      msg ||= format(DEFAULT_DUCK_FAIL_MSG, "#{obj.class} (#{obj})", methods)
      match = methods.all? { |method| obj.respond_to?(method) }
      raise msg unless match

      obj
    end

    alias_method :assert_type,            :assert_types
    alias_method :assert_arr_type,        :assert_arr_types
    alias_method :assert_common_arr_type, :assert_common_arr_types
  end
end
