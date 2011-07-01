# encoding: utf-8
module Axis
  class State
    class Filter
      class Set < Filter

        # Provides access to the "selected" field of this filter. This field may
        # be nil in which case this filter doesn't apply, or a single or array
        # of integer index values (negatives allowed) that define which values,
        # from an array of pre-defined values (on the attribute) are selected
        # and which the associated attribute must have in order to match.
        # Negative integers are used to indicate special "values" (such as NULL)
        # that may also be selected.
        attr_accessor            :selected
        alias_method :selected?, :selected

        # Returns true if the selected field is set *and* is an array, meaning
        # that a list of items are selected.
        def list? ; @selected.is_a?(Array) end

        # Returns whether or not (boolean) this filter should be applied.
        def apply?
          !selected.nil? and (!list? or !selected.empty?)
        end

      end # class Set
    end   # class Filter
  end     # class State
end       # module Axis
