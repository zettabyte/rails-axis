# encoding: utf-8
module Axis
  class State
    class Filter
      class Range < Filter

        # Provides access to the "first" field of this filter. This field may be
        # nil in which case this filter doesn't apply, or a numeric or temporal
        # value that is used to define the beginning of a range of values that
        # the associated attribute must be within (sql BETWEEN clause) in order
        # for the filter to match.
        attr_accessor         :first
        alias_method :first?, :first

        # Provides access to the "last" field of this filter. This field may be
        # nil in which case this filter doens't apply, or a numeric or temporal
        # value that is used to define the last of a range of values that the
        # associated attribute must be within (sql BETWEEN clause) in order for
        # the filter to match.
        attr_accessor       :last
        alias_method :last? :last

        # Returns whether or not (boolean) this filter should be applied.
        def apply?
          !first.nil? and !last.nil?
        end

      end # class Range
    end   # class Filter
  end     # class State
end       # module Axis
