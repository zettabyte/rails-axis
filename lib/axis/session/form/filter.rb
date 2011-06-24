# encoding: utf-8
module Axis
  class Session
    class Form
      class Filter

        DEFAULT_TYPES = [
          { :value => :equal,   :string   => "Matches".freeze, :numeric => "=".freeze, :temporal => "Equal To".freeze }.freeze,
          { :value => :begin,   :string   => "Starts With".freeze  }.freeze,
          { :value => :less,    :numeric  => "<".freeze            }.freeze,
          { :value => :before,  :temporal => "Before".freeze       }.freeze,
          { :value => :end,     :string   => "Ends With".freeze    }.freeze,
          { :value => :greater, :numeric  => ">".freeze            }.freeze,
          { :value => :after,   :temporal => "After".freeze        }.freeze,
          { :value => :le,      :numeric  => "<=".freeze           }.freeze,
          { :value => :beon,    :temporal => "Before or On".freeze }.freeze,
          { :value => :ge,      :numeric  => ">=".freeze           }.freeze,
          { :value => :afon,    :temporal => "After or On".freeze  }.freeze,
          { :value => :match,   :string   => "Contains".freeze     }.freeze,
          { :value => :true,    :boolean  => "True".freeze         }.freeze,
          { :value => :false,   :boolean  => "False".freeze        }.freeze,
          { :value => :blank,   :string   => "Is Blank".freeze,                           :only => :blank }.freeze,
          { :value => :empty,   :string   => "Is Empty".freeze,                           :only => :empty }.freeze,
          { :value => :unset,   :string   => "Is Unset".freeze, :all => "[Unset]".freeze, :only => :null  }.freeze
        ]

        ########################################################################
        class << self
        ########################################################################

          #
          # WARNING: Non-intuitive method!
          #
          # This creates, not an Axis::Session::Form::Filter instance, but an
          # Axis::State::Filter instance for the provided attribute (must be
          # searchable)
          #
          def create(form, attribute)
            raise ArgumentError, "provided attribute isn't searchable: #{attribute.name}" unless attribute.searchable?
            Axis::State::Filter.new(attribute.name)
          end

        ########################################################################
        end
        ########################################################################

        #
        # Create a wrapper around a State::Filter instance and an attribute on
        # the model associated with the provided form.
        #
        def initialize(form, filter)
          @form      = form   # containing form
          @filter    = filter # this is the state filter
          @attribute = form.searchables[filter.name]
          raise ArgumentError, "invalid state filter; it's name doesn't match " +
            "any searchable attribute: #{filter.name}" unless @attribute
        end

        attr_reader :form      # containing form
        attr_reader :filter    # Axis::State::Filter instance
        attr_reader :attribute # Axis::Attribute instance

        #
        # Retrieve the model this filter operates on
        #
        def model
          @model ||= form.model
        end

        #
        # Retrieve the name of the attribute this filter operates on
        #
        def name
          @name ||= attribute.name
        end

        #
        # Retrieve the display name of the attribute this filter operates on
        #
        def display
          @display ||= attribute.filter.display || name.humanize
        end

        #
        # Retrieve the filter type
        #
        def type
          @type ||= attribute.filter.type
        end

        #
        # Retrieve the attribute type
        #
        def attribute_type
          @attribute_type ||= attribute.type
        end

        #
        # Update the form's filter according to the provided "changes". Returns
        # a boolean indicating whether any changes were made or not.
        #
        def update(changes = nil)
          return   false unless changes.is_a?(Hash) and !changes.empty?
          result = false
          Rails.logger.debug "\n\n\n"
          Rails.logger.debug "Trying to update filter #{display} (attribute #{name} on model #{model.name})"
          Rails.logger.debug "--Filter Details: #{type} filter on an #{attribute_type} attribute"
          Rails.logger.debug "--Existing state of filter: #{filter.options.inspect}"
          Rails.logger.debug "--Changes to apply: #{changes.inspect}"
          case type
          when :default
            old_value = filter.value
            new_value = changes[:value]
            old_type  = DEFAULT_TYPES.find { |t| t[:value].to_s == filter.selection }
            new_type  = DEFAULT_TYPES.find { |t| t[:value].to_s == changes[:type]   }
            if  new_type                 and new_type != old_type       and
              ( new_type[attribute_type]  or new_type[:all]           ) and
              (!new_type.has_key?(:only)  or attribute.filter.options[new_type[:only]])
              filter.selection = new_type[:value].to_s
              if new_type[:only]
                filter.value = new_value = old_value = nil
                result       = true
              elsif old_type and old_type[:only]
                result       = true
              else
                result       = !!old_value
              end
            end
            if new_value.is_a?(String) and new_value != old_value and new_type and !new_type[:only]
              begin
                case attribute_type
                when :numeric  then old_value, new_value = [Normalize.numeric(old_value),  Validate.numeric(new_value) ]
                when :temporal then old_value, new_value = [Normalize.temporal(old_value), Validate.temporal(new_value)]
                when :boolean  then old_value, new_value = [Normalize.boolean(old_value),  Validate.boolean(new_value) ]
                end
              rescue ArgumentError
                new_value = old_value
              end
              if new_value != old_value
                filter.value = new_value.to_s
                result       = true
              end
            end

          when :set
            old_value = filter.value
            new_value = changes[:value]
            if multi?
              if new_value.is_a?(Array) and (old_value.nil? or new_value.sort != old_value.sort)
                filter.value = new_value.sort
                result      = true
              end
            else
              if new_value.is_a?(String) and new_value != old_value
                filter.value = new_value
                result      = true
              end
            end

          when :null    # TODO
          when :boolean # TODO
          when :pattern # TODO
          when :range   # TODO
          end

          #
          # Update the "negated" or "not-ed" state of the filter...
          #
          negate = Validate.boolean(changes[:negate]) rescue nil
          unless negate.nil? or !attribute.filter.options[:not]
            result         = true if negate != filter.negated?
            filter.negated = negate
          end
          result
        end

        #
        # Return an array (of two-element arrays) containing the appropriate list of
        # values and display names for a filter, of type :default, for the type of
        # filtration (the selection field's value) to perform.
        #
        def default_type_options
          raise ArgumentError, "invalid type of filter: #{@attribute.type}" unless @attribute.type == :default
          type   = @attribute.attribute_type
          result = DEFAULT_TYPES.reject do |t|
            next(true)  unless t[type] or t[:all] # omit entry if it doesn't apply to this filter type
            next(false) unless t[:only]           # keep unless entry only applies when certain attributes present
            begin ; !@attribute.send(t[:only])    # omit if attribute isn't set (true)
            rescue NoMethodError ; true           # omit entry since attribute not even present
            end
          end.map do |t|
            [t[type] || t[:all], t[:value].to_s]
          end
          result.unshift(["", ""]) if type == :boolean
          result
        end

        #
        # Return an array (of two-element arrays) containing the appropriate list of
        # values and display names for a filter, of type :set, for the list of legal
        # values the user can filter a field by.
        #
        def set_options
          raise ArgumentError, "invalid type of filter: #{@attribute.type}" unless @attribute.type == :set
          result  = []
          result << ["", ""] unless @attribute.multi?
          @attribute.values.each_with_index do |v, i|
            result << [v, "#{i}:#{v}"]
          end
          if @attribute.attribute_type == :string
            result << ["Is Blank", "blank:"] if @attribute.blank?
            result << ["Is Empty", "empty:"] if @attribute.empty?
          end
          result << ["Is Unset", "unset:"] if @attribute.null?
          result
        end

        #
        # Returns true if this filter actually has data (in the State::Filter) such
        # that it can be applied to actually filter out records and have an effect.
        # Otherwise it returns false.
        #
        def apply?
          !@state.options.empty? and @state.options.any? { |k, v| v }
        end

        #
        # Initializes the associated state filter's attributes according to the
        # associated attribute filter type's default state; returns self for
        # chainability...
        #
        def defaults
          type = @attribute.type
          @state.value   = nil   # used by all but :set filters
          @state.start   = nil   # really only used by :range filters
          @state.end     = nil   # really only used by :range filters
          @state.negated = false # used by most filters
          if type == :default or type == :set
            @state.selection = nil
            @state.selection = "equal" if type == :default and @attribute.attribute_type != :boolean
          end
          self
        end

      end # class  Filter
    end   # class  Form
  end     # class  Session
end       # module Axis
