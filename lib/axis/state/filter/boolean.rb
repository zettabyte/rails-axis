# encoding: utf-8
module Axis
  class State
    class Filter
      class Boolean < Filter

        # Provides access to the "value" field of this filter. This field may be
        # nil, in which case the filter doesn't apply, or a boolean value,
        # indicating what the boolean disposition of the associated attribute
        # must be in order to indicate a match.
        attr_accessor         :value
        alias_method :value?, :value

        # Returns whether or not (boolean) this filter should be applied.
        def apply?
          !value.nil?
        end

      end # class Boolean
    end   # class Filter
  end     # class State
end       # module Axis
