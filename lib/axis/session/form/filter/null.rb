# encoding: utf-8
module Axis
  class Session
    class Form
      class Filter
        class Null

          #
          # Apply this filter on the provided scope
          #
          def apply(scope)
              field = (negated? ^ null?) ? :field : :field.not_eq
              scope.where(field => nil)
          end

          #
          # Generate a hash representing an individual sql WHERE-clause (using
          # the MetaWhere gem features) for this filter on the provided column
          # name.
          #
          # If the filter doesn't apply then just return nil.
          #
          def where_clause(column)
            return nil unless apply?
            if non_true?
              # when value is false, instead of searching for false, search for
              # those that don't equal true...
              column = column.intern.send((negated? ^ value?) ? :eq : :not_eq)
              { column => true }
            else
              # simple filter searching for an explicit true or false
              { column => (negated? ^ value?) }
            end
          end

          #
          # Update the form's filter according to the provided "changes". Returns
          # a boolean indicating whether any changes were made or not.
          #
          def private_update(changes)
            return false if radio? and changes[:value].nil?
            new_value = Validate.boolean(changes[:value]) rescue false
            result    = new_value != value
            value     = new_value
            result
          end

          #
          # After a new state filter is created it might not have the best set
          # of default values since it isn't aware of the associated attribute's
          # settings. This is called when the state filter is first constructed
          # and "wrapped" by the session filter to set up these context-aware
          # defaults.
          #
          def initial_defaults
            # Immediately enable this filter if it's checkbox-style
            value = false if checkbox?
          end

          #
          # Update the form's filter according to the provided "changes". Returns
          # a boolean indicating whether any changes were made or not.
          #
          def update(changes = nil)
            result   = false
            new_null = changes[:null]             rescue nil
            new_null = Validate.boolean(new_null) rescue nil unless new_null.nil?
            unless new_null == null? or (multi? and new_null.nil?)
              null   = new_null
              result = true
            end
            # Call the super-class implementation to do any common work
            super ? true : result
          end

        end # class  Null
      end   # class  Filter
    end     # class  Form
  end       # class  Session
end         # module Axis
