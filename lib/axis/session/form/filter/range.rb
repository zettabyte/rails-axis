# encoding: utf-8
module Axis
  class Session
    class Form
      class Filter
        class Range

          #
          # Apply this filter on the provided scope
          #
          def apply(scope)
            if apply?
              scope.where(:field => (negated? ^ true?))
            else
              scope
            end
          end

          #
          # Update the form's filter according to the provided "changes". Returns
          # a boolean indicating whether any changes were made or not.
          #
          def update(changes = nil)
            result   = false
            source   = changes.is_a?(Hash) ? changes.dup : {}
            new_true = source[:true]
            new_true = Validate.boolean(new_true) rescue nil unless new_true.nil?
            unless new_true == true? or (multi? and new_true.nil?)
              self.true = new_true
              result    = true
            end
            # Call the super-class implementation to do any common work
            super ? true : result
          end


          when :range
            old_start = state.start
            old_end   = state.end
            if attribute_type == :numeric
              new_start = Validate.numeric(changes[:start]) rescue old_start
              new_end   = Validate.numeric(changes[:end])   rescue old_end
            elsif attribute_type == :temporal
              new_start = Validate.temporal(changes[:start]) rescue old_start
              new_end   = Validate.temporal(changes[:end])   rescue old_end
            end
            if old_start != new_start or old_end != new_end
              result = true if (old_start and old_end) or (new_start and new_end)
              state.start = new_start
              state.end   = new_end
            end
          end


        end # class  Range
      end   # class  Filter
    end     # class  Form
  end       # class  Session
end         # module Axis
