# encoding: utf-8
module Axis
  class Session
    class Form
      class Filter

        PARAMS        = "filter".freeze # sub-hash key (in params) for filters
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
        ].freeze
        SET_SPECIAL_TYPES = DEFAULT_TYPES.select { |t| t.has_key?(:only) }.freeze

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
          default_state # make sure State::Filter's have basic options set
        end

        #
        # Determine this filters current "id" (the index of its associated state
        # filter object stored in the state's filter collection). This isn't
        # cached since it could change as filters are created and destroyed.
        #
        def id
          form.filters.array.each_with_index do |f, i|
            return i if f == @filter
          end
          nil # I don't have an id; I'm not in the collection!
        end

        attr_reader :form      # containing form
        attr_reader :filter    # Axis::State::Filter instance
        attr_reader :attribute # Axis::Attribute instance

        #
        # Used to generate the id string, used in HTML elements (and referenced
        # by CSS rules), for a given attribute associated with this filter. The
        # attribute here is defined by a list of values that hierarchically
        # define the attribute. This would be the same set of keys as passed to
        # the #attr_name method, but we're instead generating an HTML id which
        # is used on any/all elements, not just form controls. If no keys are
        # specified, then the HTML id of the filter itself is returned.
        #
        # Examples:
        #   filter.attr_id         => "axis-2-filter-3"
        #   filter.attr_id("type") => "axis-2-filter-3-type"
        #
        def attr_id(*keys)
          form.attr_id(*keys.unshift(PARAMS.dup, id))
        end

        #
        # Used to generate the name, used in HTML form controls, for a given
        # attribute associated with this filter. The attribute here is defined
        # by a list of values that would be the sequence of keys needed to look
        # up the attribute value in the resulting params hash.
        #
        # Example:
        #   filter.attr_name("type") => "axis[2][filter][3][type]"
        #
        def attr_name(*keys)
          form.attr_name(*keys.unshift(PARAMS.dup, id))
        end

        #
        # Used to generate a hash which may be provided to URL-constructing
        # helpers in order to create a query-string key and value that, when it
        # is processed in a future request, will yield a params hash entry that
        # needs the same chain (hierarchy) of keys to access the provided value.
        #
        # The last parameter is considered the value and all other parameters
        # are considered part of the key chain.
        #
        # Example:
        #   filter.attr_hash("type", "equal")
        #     => { "axis" => { 2 => { "filter" => { "type" => "equal" } } } }
        #     => "axis[2][filter]=equal"  # after helper converts to querystring
        #   params["axis"]["2"]["filter"] # next request after user clicks link
        #     => "equal"
        #
        # If the last parameter is a hash, then instead of being considered the
        # value it will be considered a "merge" hash and the second-to-the-last
        # parameter will be considered the value. If a "merge" hash is present,
        # then the hash this method normally constructs will be merged with the
        # provided "merge" hash and the result of the merge returned.
        #
        # The merge will favor values in the new hash this method generates over
        # values in the "merge" if there is any conflict.
        #
        def attr_hash(*keys_and_value)
          form.attr_hash(*keys_and_value.unshift(PARAMS.dup, id))
        end

        #
        # Retrieve the model this filter operates on
        #
        def model
          form.model
        end

        #
        # Retrieve the name of the attribute this filter operates on
        #
        def name
          attribute.name
        end

        #
        # Retrieve the display name of the attribute this filter operates on
        #
        def display
          attribute.display
        end

        #
        # Apply this filter on the provided scope
        #
        def apply(scope)
          clause = nil
          case type
          when :default

            #
            #
            #
            variation = DEFAULT_TYPES.find { |t| t[:value].to_s == filter.selection }
            if variation
              if attribute_type == :boolean
                if variation[:value] == :true
                  clause = !not? or !filter.negated # true; false if negated
                elsif variation[:value] == :false
                  clause = not? and filter.negated # false; true if negated
                end
                clause = Hash[*attribute.columns.map { |c| [c, clause] }.flatten] unless clause.nil?
              elsif filter.value
                case attribute_type
                when :temporal
                  clause = case variation[:value]
                  when :equal  then (not? and filter.negated) ? :not_eq : :eq
                  when :before then (not? and filter.negated) ? :gteq   : :lt
                  when :after  then (not? and filter.negated) ? :lteq   : :gt
                  when :beon   then (not? and filter.negated) ? :gt     : :lteq
                  when :afon   then (not? and filter.negated) ? :lt     : :gteq
                  else ; nil
                  end
                  if clause
                    clause = Hash[*attribute.columns.map { |c| [c.intern.send(clause), filter.value] }.flatten]
                  end
                when :numeric
                  clause = case variation[:value]
                  when :equal   then (not? and filter.negated) ? :not_eq : :eq
                  when :less    then (not? and filter.negated) ? :gteq   : :lt
                  when :greater then (not? and filter.negated) ? :lteq   : :gt
                  when :le      then (not? and filter.negated) ? :gt     : :lteq
                  when :ge      then (not? and filter.negated) ? :lt     : :gteq
                  else ; nil
                  end
                  if clause
                    clause = Hash[*attribute.columns.map { |c| [c.intern.send(clause), filter.value] }.flatten]
                  end
                when :string
                end
              end
            end

          when :set
          when :null
          when :boolean
          when :pattern
          end

          #
          # Filter based on our clause, if we have one. Otherwise, return the
          # scope unmodified...
          #
          clause ? scope.where(clause) : scope
        end

        #
        # Update the form's filter according to the provided "changes". Returns
        # a boolean indicating whether any changes were made or not.
        #
        def update(changes = nil)
          changes ||= {}
          result    = false
          Rails.logger.debug "\n\n\n"
          Rails.logger.debug "Trying to update filter '#{display}' (attribute '#{name}' on model '#{model.name}')"
          Rails.logger.debug "--Filter Details: '#{type}' filter on '#{attribute_type}' attribute"
          Rails.logger.debug "--Existing state of filter: #{filter.options.inspect}"
          Rails.logger.debug "--Changes to apply: #{changes.inspect}"

          case type
          when :default
            old_type = DEFAULT_TYPES.find { |t| t[:value].to_s == filter.selection }
            new_type = DEFAULT_TYPES.find { |t| t[:value].to_s == changes[:type]   }
            if attribute_type == :boolean
              #
              # Handle the boolean attribute-typed :default filters separately
              #
              if new_type != old_type
                filter.selection = new_type ? new_type[:value].to_s : nil
                result           = true
              end
            else

              #
              # Preload values; we may update them when changing selection
              #
              old_value = filter.value
              new_value = changes[:value]

              #
              # First update this :default-typed filter's sub-type selection...
              #
              if  new_type                 and new_type != old_type       and
                ( new_type[attribute_type]  or new_type[:all]           ) and
                (!new_type.has_key?(:only)  or attribute.filter.options[new_type[:only]])
                filter.selection = new_type[:value].to_s
                if new_type[:only]
                  filter.value = new_value = old_value = nil
                  result = true # switching to :only sub-type => nuke filter val
                elsif old_type and old_type[:only]
                  result = true # switching from :only sub-type requires refresh
                else
                  # return true (refresh recordset) if we had/have a filter
                  # value and we switched filter types; otherwise, if there was
                  # no filter value, then even though we changed types, there's
                  # no impact (both the old state and new state are unapplied,
                  # empty filters).
                  result = !!old_value
                end
              end

              #
              # Convert any new filter values to their native data types and
              # update saved filter's value...
              #
              unless new_value.blank?
                if attribute_type == :numeric
                  new_value = Validate.numeric(new_value) rescue old_value
                elsif attribute_type == :temporal
                  begin
                    new_value = Validate.temporal(new_value)
                    new_value = new_value.to_date if attribute.type == :date
                  rescue ArgumentError
                    new_value = old_value
                  end
                end
              end
              if new_value != old_value and new_type and !new_type[:only]
                filter.value = new_value.blank? ? nil : new_value
                result       = true
              end
            end

          when :set
            old_value = filter.value
            new_value = changes[:value]
            if multi?
              if new_value.is_a?(Array)
                new_value    = new_value.map { |i| validate_set_option(i) rescue nil }.reject { |i| i.blank? }.sort
                result       = true if !old_value.is_a?(Array) or new_value != old_value
                filter.value = new_value
              elsif new_value.blank?
                result       = true unless old_value.blank?
                filter.value = nil
              end
            else
              new_value = validate_set_option(new_value) rescue nil
              if new_value != old_value
                filter.value = new_value
                result       = true
              end
            end

          when :null
            old_value = filter.value
            new_value = Validate.boolean(changes[:value]) rescue nil
            unless new_value == old_value or (multi? and new_value.nil?)
              filter.value = new_value
              result       = true
            end

          when :boolean
            old_value = filter.value
            new_value = changes[:value]
            new_value = Validate.boolean(new_value) rescue nil unless new_value.nil?
            unless new_value == old_value or (multi? and new_value.nil?)
              filter.value = new_value
              result       = true
            end

          when :pattern
            new_value    = changes[:value]
            new_value    = nil unless new_value.is_a?(String) and !new_value.blank?
            result       = new_value != filter.value
            filter.value = new_value

          when :range
            old_start = filter.start
            old_end   = filter.end
            if attribute_type == :numeric
              new_start = Validate.numeric(changes[:start]) rescue old_start
              new_end   = Validate.numeric(changes[:end])   rescue old_end
            elsif attribute_type == :temporal
              new_start = Validate.temporal(changes[:start]) rescue old_start
              new_end   = Validate.temporal(changes[:end])   rescue old_end
            end
            if old_start != new_start or old_end != new_end
              result = true if (old_start and old_end) or (new_start and new_end)
              filter.start = new_start
              filter.end   = new_end
            end
          end

          #
          # Update the "negated" or "not-ed" state of the filter...
          #
          negate = Validate.boolean(changes[:negate]) rescue nil
          if not?
            result = true if negate != filter.negated?
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
          raise ArgumentError, "invalid type of filter: #{type}" unless type == :default
          result = DEFAULT_TYPES.reject do |t|
            next(true)  unless t[attribute_type] or t[:all]
            next(false) unless t[:only]
            begin ; !attribute.filter.send(t[:only])
            rescue NoMethodError ; true
            end
          end.map do |t|
            [t[attribute_type] || t[:all], t[:value].to_s]
          end
          result.unshift(["", ""]) if attribute_type == :boolean
          result
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

        ########################################################################
        private
        ########################################################################

        #
        # Make sure the referenced Axis::State::Filter instance has basic fields
        # (options) initialized (to at least nil) given the type of attribute
        # its associated with.
        #
        def default_state
          o = @filter.options
          @filter.value   = nil   unless o.has_key?("value"  ) # used by all but :set filters
          @filter.start   = nil   unless o.has_key?("start"  ) # really only used by :range filters
          @filter.end     = nil   unless o.has_key?("end"    ) # really only used by :range filters
          @filter.negated = false unless o.has_key?("negated") # used by most filters
          unless o.has_key?("selection") or (type != :default and type != :set)
            @filter.selection = nil
            @filter.selection = "equal" if type == :default and attribute_type != :boolean
          end
        end

        #
        # Proxy all method calls we don't respond to first to the attribute's
        # filter definition class, then to the state's filter class.
        #
        def method_missing(name, *args, &block)
          begin ; return @attribute.filter.send(name, *args, &block) ; rescue NoMethodError ; end
          begin ; return @filter.send(name, *args, &block)           ; rescue NoMethodError ; end
          super
        end

      end # class  Filter
    end   # class  Form
  end     # class  Session
end       # module Axis
