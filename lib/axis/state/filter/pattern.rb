# encoding: utf-8
module Axis
  class State
    class Filter
      class Pattern < Filter

        # Provides access to the "value" field of this filter. This field may be
        # nil in which case this filter doesn't apply, or a string value that is
        # used to match against the associated attribute using an sql LIKE
        # clause. This string may contain special sql LIKE-clause characters
        # such as '%' and '_'.
        attr_accessor         :value
        alias_method :value?, :value

        # Returns whether or not (boolean) this filter should be applied.
        def apply?
          !value.nil?
        end

      end # class Pattern
    end   # class Filter
  end     # class State
end       # module Axis
