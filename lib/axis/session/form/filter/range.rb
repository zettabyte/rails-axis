# encoding: utf-8
require 'axis/validate'

module Axis
  class Session
    class Form
      class Filter
        class Range < Filter

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
          # This gets a formatted, displayable string version of #first. It will
          # apply any custom formatter for the filter value.
          #
          # TODO: implement custom formatter block (in attribute filter def.) to
          #       control how #first and #last data-type values get formatted to
          #       strings...
          #
          def rendered_first
            first.to_s
          end

          #
          # This gets a formatted, displayable string version of #last. It will
          # apply any custom formatter for the filter value.
          #
          # TODO: implement custom formatter block (in attribute filter def.) to
          #       control how #first and #last data-type values get formatted to
          #       strings...
          #
          def rendered_last
            last.to_s
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
            result = { column => first..last }
            negated? ? -result : result
          end

          #
          # Update the form's filter according to the provided "changes". Returns
          # a boolean indicating whether any changes were made or not.
          #
          def private_update(changes)
            new_first  = process_input(changes[:first])
            new_last   = process_input(changes[:last])
            result     = new_first != first
            result   ||= new_last  != last
            self.first = new_first
            self.last  = new_last
            result
          end

          #
          # Utility method used by #private_update to convert an input string
          # into a data object of a type appropriate for the filter's attribute-
          # type.
          #
          def process_input(val)
            if attribute_type == :numeric
              Validate.numeric(val) rescue nil
            else # attribute_type == :temporal
              tmp = Validate.temporal(val) rescue nil
              tmp and attribute.type == :date ? tmp.to_date : tmp
            end
          end

        end # class  Range
      end   # class  Filter
    end     # class  Form
  end       # class  Session
end         # module Axis
