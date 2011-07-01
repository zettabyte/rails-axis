# encoding: utf-8
module Axis
  class State
    class Filter
      class Default < Filter

        # Provides access to the "comparison" field of this filter. This field
        # may be nil in which case this filter doesn't apply, or a string value
        # indicating the type of comparison that should be made between the
        # associated attribute and the "value" field (below).
        attr_accessor              :comparison
        alias_method :comparison?, :comparison
        
        # Provides access to the "value" field of this filter. This field may be
        # nil in which case this filter doesn't apply, or a string, numeric,
        # temporal, or boolean value that should be compared with the associated
        # attribute's value. This field isn't technically required for this kind
        # of filter on boolean attributes, but IT IS OFFICIALLY REQUIRED anyway
        # in order to simplify the structure of the system and allow the #apply?
        # method to be able to determine whether or not this filter applies.
        # Also, there are special values for the "comparison" field on all types
        # of associated attributes that also don't make use of the value in
        # "value"; for these, YOU MUST store true in "value" so #apply? works
        # correctly.
        attr_accessor         :value
        alias_method :value?, :value

        # Returns whether or not (boolean) this filter should be applied.
        def apply?
          !comparison.nil? and !value.nil?
        end

      end # class Default
    end   # class Filter
  end     # class State
end       # module Axis
