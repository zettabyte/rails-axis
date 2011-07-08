# encoding: utf-8
require 'axis/normalize'

module Axis
  class Session
    class Form
      class Filter
        class Set < Filter

          # These are the names of the "special" values in the order they should
          # be listed as options to the user (as/if they're available). These
          # are available if #include_null?, #include_blank?, and/or
          # #include_empty? yield true respectively.
          #
          # The real trick here is that these names are keys to the SPECIAL_*
          # constants (below) and the string equivalent of these values, with
          # the "include_" prefix and the "?" suffix matches the name of the
          # query method used to determine if this special option is available
          # on this filter.
          SPECIALS = [ :null, :empty, :blank ].freeze

          # The display labels for the special (null, blank, or empty) values
          # that may be available (depending on #include_null?, etc).
          SPECIAL_LABELS = {
            :null  => "Unset".freeze,
            :empty => "Empty".freeze,
            :blank => "Blank".freeze
          }.freeze

          # The values associated with the special (null, blank, or empty)
          # values that may be available (depending on #include_null?, etc).
          SPECIAL_VALUES = {
            :null  => -1,
            :empty => -2,
            :blank => -3
          }.freeze

          #
          # After a new state filter is created it might not have the best set
          # of default values since it isn't aware of the associated attribute's
          # settings. This is called when the state filter is first constructed
          # and "wrapped" by the session filter to set up these context-aware
          # defaults.
          #
          def initialize_defaults!
            # default state is all empty
          end

          #         
          # Return an array (of two-element arrays) containing the appropriate
          # list of values and display names for this type of set filter.
          #         
          def options
            result  = []
            result << ["", ""] unless multiple?
            ordering.each_with_index do |v, i|
              result << [values.is_a?(Hash) ? values[v] : v, i]
            end
            SPECIALS.each do |s|
              next unless self.send("include_#{s}?")
              result << [SPECIAL_LABELS[s], SPECIAL_VALUES[s]]
            end
            result
          end

          private

          #
          # Generate a hash representing an individual sql WHERE-clause (using
          # the MetaWhere gem features) for this filter on the provided column
          # name.
          #
          # If the filter doesn't apply then just return nil.
          #
          def where_clause(column)
            column = column.intern
            if list?
              selected.map do |index|
                where_sub_clause(column, index)
              end.compact.reduce do |clause_1, clause_2|
                negated? ? (clause_1 & clause_2) : (clause_1 | clause_2)
              end
            else # single selection from set of values
              where_sub_clause(column, selected)
            end
          end

          #
          # Utility helper used by #where_clause to construct an individual sub-
          # clause that will be be combined with other sub-clauses to build the
          # full where clause. The provided index is the selected element to
          # either match or not match (if negated).
          #
          # The column will have already been converted to a symbol.
          #
          def where_sub_clause(column, index)
            index  = validate_selected_index(index) rescue nil
            column = column.not_eq if negated? # pre-apply negation
            return nil unless index
            if index < 0
              case index
              when SPECIAL_VALUES[:null]  then { column => nil }
              when SPECIAL_VALUES[:empty] then { column => ""  }
              when SPECIAL_VALUES[:blank]
                if negated?
                  { column => nil } & { column => "" } # column already #not_eq
                else
                  { column => nil } | { column => "" }
                end
              end
            else # index >= 0
              value = ordering[index]
              value = values[value] if values.is_a?(Hash)
              { column => value } # column pre-negated
            end
          end

          #
          # Update the form's filter according to the provided "changes". Returns
          # a boolean indicating whether any changes were made or not.
          #
          def private_update(changes)
            new_selected = changes[:selected]
            if new_selected.is_a?(Array)
              new_selected = new_selected.map { |i| validate_selected_index(i) rescue nil }.compact.sort
              new_selected = nil if new_selected.empty? or !multiple?
            else
              new_selected = validate_selected_index(new_selected) rescue nil
            end
            result        = new_selected != selected
            self.selected = new_selected
            result
          end

          #
          # Custom validator for a selected index value.
          #
          def validate_selected_index(arg)
            result = Normalize.integer(arg)
            raise ArgumentError, "invalid type for set filter index: #{arg.class}" unless result.is_a?(Fixnum)
            if result < 0
              raise ArgumentError, "invalid 'special' index value for set filter: #{result}" unless
                SPECIAL_VALUES.values.include?(result)
            else # result >= 0
              raise ArgumentError, "invalid index value for set filter: #{result}" unless result < ordering.length
            end
            result
          end

        end # class  Set
      end   # class  Filter
    end     # class  Form
  end       # class  Session
end         # module Axis
