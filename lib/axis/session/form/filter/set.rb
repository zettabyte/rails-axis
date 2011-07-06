# encoding: utf-8
module Axis
  class Session
    class Form
      class Filter
        class Set

        SET_SPECIAL_TYPES = DEFAULT_TYPES.select { |t| t.has_key?(:only) }.freeze

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

          when :set
            old_value = state.value
            new_value = changes[:value]
            if multi?
              if new_value.is_a?(Array)
                new_value    = new_value.map { |i| validate_set_option(i) rescue nil }.reject { |i| i.blank? }.sort
                result       = true if !old_value.is_a?(Array) or new_value != old_value
                state.value = new_value
              elsif new_value.blank?
                result       = true unless old_value.blank?
                state.value = nil
              end
            else
              new_value = validate_set_option(new_value) rescue nil
              if new_value != old_value
                state.value = new_value
                result       = true
              end
            end

        #         
        # Return an array (of two-element arrays) containing the appropriate list of
        # values and display names for a filter, of type :set, for the list of legal
        # values the user can filter a field by.
        #         
        def set_options
          raise ArgumentError, "invalid type of filter: #{type}" unless type == :set
          result  = [] 
          result << ["", ""] unless multi? 
          values.each_with_index do |v, i| 
            result << [v, i.to_s]
          end     
          SET_SPECIAL_TYPES.reject do |t|
            next(true) unless t[attribute_type] or t[:all] 
            begin ; !attribute.filter.send(t[:only])
            rescue NoMethodError ; true
            end 
          end.each_with_index do |t, i|
            result << [t[attribute_type] || t[:all], (i * -1 - 1).to_s]
          end
          result
        end

        def normalize_set_option(arg)
          result = arg.is_a?(Symbol) ? arg.to_s : arg
          (result.is_a?(Numeric) or (result.is_a?(String) and result =~ /\A-?\d+\z/)) ? result.to_i : result
        end
        
        def validate_set_option(arg)
          result = normalize_set_option(arg)
          range  = (0 - set_options.length)...(values.length)
          case result
          when Fixnum then raise ArgumentError, "invalid value for set option index: #{result}"   unless range.include?(result)
          when String then raise ArgumentError, "invalid value for set option index: #{result}"   unless result.blank?
          else ;           raise ArgumentError, "invalid type for set option index: #{arg.class}" unless result.nil?
          end
          result
        end


        end # class  Set
      end   # class  Filter
    end     # class  Form
  end       # class  Session
end         # module Axis
