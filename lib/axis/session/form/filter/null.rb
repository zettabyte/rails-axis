# encoding: utf-8
require 'axis/validate'

module Axis
  class Session
    class Form
      class Filter
        class Null < Filter

          #
          # After a new state filter is created it might not have the best set
          # of default values since it isn't aware of the associated attribute's
          # settings. This is called when the state filter is first constructed
          # and "wrapped" by the session filter to set up these context-aware
          # defaults.
          #
          def initialize_defaults!
            # Immediately enable this filter if it's checkbox-style
            self.value = false if checkbox?
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
            match_null = negated? ^ value?
            column     = column.intern
            column     = column.not_eq unless match_null # pre-apply negation
            case
            when use_null?  then { column => nil }
            when use_empty? then { column => ""  }
            when use_blank?
              if match_null
                { column => nil } | { column => "" }
              else
                { column => nil } & { column => "" } # column already #not_eq
              end
            end
          end

          #
          # Update the form's filter according to the provided "changes". Returns
          # a boolean indicating whether any changes were made or not.
          #
          def private_update(changes)
            return false if radio? and changes[:value].nil?
            new_value  = Validate.boolean(changes[:value]) rescue false
            result     = new_value != value
            self.value = new_value
            result
          end

        end # class  Null
      end   # class  Filter
    end     # class  Form
  end       # class  Session
end         # module Axis
