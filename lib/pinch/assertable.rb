
module Wgit

  # @author Michael Telford
  # Module containing assert methods including type checking which can be used 
  # for asserting the integrity of method definitions etc. 
  module Assertable
      DEFAULT_TYPE_FAIL_MSG = "Expected: %s, Actual: %s"
      WRONG_METHOD_MSG = "arr must be Enumerable, use a different method"
      DEFAULT_DUCK_FAIL_MSG = "%s doesn't respond_to? %s"
    
      # obj.instance_of? must return true for one of the types listed in 
      # type_or_types or an exception is thrown using msg if provided. 
      # type_or_types can be a single Class or an Enumerable of Class objects, 
      # Strings and Symbols will not work. 
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
      # type_or_types or an exception is thrown using msg if provided. 
      # type_or_types can be a single Class or an Enumerable of Class objects, 
      # Strings and Symbols will not work. 
      def assert_arr_types(arr, type_or_types, msg = nil)
          raise WRONG_METHOD_MSG unless arr.respond_to?(:each)
          arr.each do |obj|
              assert_types(obj, type_or_types, msg)
          end
      end
    
      # The obj_or_objs must respond_to? all of the given methods or an 
      # Exception is raised using msg or a default message.
      # Returns obj_or_objs on sucessful assertion.
      def assert_respond_to(obj_or_objs, methods, msg = nil)
          if obj_or_objs.respond_to?(:each)
              obj_or_objs.each do |obj|
                  _assert_respond_to(obj, methods, msg)
              end
          else
              _assert_respond_to(obj_or_objs, methods, msg)
          end
          obj_or_objs
      end
    
      private
    
      def _assert_respond_to(obj, methods, msg = nil)
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
