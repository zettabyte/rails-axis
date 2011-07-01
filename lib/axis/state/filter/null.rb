# encoding: utf-8
module Axis
  class State
    class Filter
      class Null < Filter

        # Provides access to the "null" field of this filter. This field may be
        # nil in which case this filter doesn't apply, or a boolean value
        # indicating whether the associated attribute should be NULL or not for
        # the filter to match.
        attr_accessor        :null
        alias_method :null?, :null

        # Returns whether or not (boolean) this filter should be applied.
        def apply?
          !null.nil?
        end

      end # class Null
    end   # class Filter
  end     # class State
end       # module Axis
