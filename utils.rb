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
    
    # NOTE: If the obj_or_objs is an Array and you want to check for an array 
    # rather than the objects within then you need place the array obj inside 
    # an array e.g. Utils.is_a?([array], Array)
    # Otherwise each array element is checked against type_or_types.
    def self.is_a?(obj_or_objs, type_or_types, msg = nil)
        if obj_or_objs.is_a?(Array)
            obj_or_objs.each do |obj|
                is_type?(obj, type_or_types, msg)
            end
        else
            is_type?(obj_or_objs, type_or_types, msg)
        end
        true
    end

    def self.is_type?(obj, type_or_types, msg = nil)
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
                    raise "obj.is_a?(#{type_or_types}) must be true"
                else
                    raise msg
                end
            end
        else
            type = type_or_types
            unless obj.is_a?(type)
                if (msg.nil?)
                    raise "obj.is_a?(#{type}) must be true"
                else
                    raise msg
                end
            end
        end
        true
    end
    
    private_class_method :is_type?
end
