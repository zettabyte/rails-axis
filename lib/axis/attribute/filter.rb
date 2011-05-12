# vim: fileencoding=utf-8:
module Axis
  class Attribute

    #
    # An instance of Axis::Attribute::Filter is used to represent part of the
    # metadata stored in Axis::Attribute instances about a literal or logical
    # model attribute. Specifically how you may filter records on said
    # attribute.
    #
    # Axis::Attribute instances may hold a single reference to an instance if
    # the attribute it describes may be used to filter or search for a single
    # or set of records handled by the model class associated with the
    # attribute.
    #
    # A filter may be one of several types, as defined in the
    # Axis::Attribute::Filter::TYPES constant. Also, a filter will be associated
    # with an attribute which also has a type (see the
    # Axis::Attribute::TYPES and Axis::Attribute::ALIASES constants). The filter
    # will store its own copy/reference to the associated attribute type.
    #
    # The combination of the filter type and the attribute type determines what
    # other option values are recognized for a filter.
    #
    class Filter

      #
      # The list of the supported types of Axis::Attribute::Filter instances.
      #
      TYPES = [ :default, :set, :null, :boolean, :range, :pattern ].freeze

      #
      # OPTIONS is the total set of all supported options for all types of
      # Axis::Attribute::Filter instances. BOOLEAN_OPTIONS is the subset of
      # OPTIONS that are boolean. Thus all options in OPTIONS that aren't also
      # in BOOLEAN_OPTIONS are ones whose values aren't boolean (and thus don't
      # support attribute accessors with a trailing question-mark).
      #
      # While the values in OPTIONS do define the legal "keys" for the optional
      # options hash, for any given type and attribute_type combination, only a
      # subset are considered valid.
      #
      OPTIONS         = [ :not, :null, :blank, :empty, :multi, :false, :values ].freeze
      BOOLEAN_OPTIONS = (OPTIONS -                                    [:values]).freeze

      #
      # Create an Axis::Attribute::Filter instance of the specified type that
      # references an Axis::Attribute of the specified attribute_type and that
      # is itself associated with the specified model class. Create this filter
      # using the provided (optional for some filter types) options and possibly
      # an associated code block that performs the actual filtration.
      #
      def initialize(type, attribute_type, model, options = {}, &block)
        @type           = type.is_a?(String)           : type.intern           : type
        @attribute_type = attribute_type.is_a?(String) : attribute_type.intern : attribute_type
        @model          = model
        @block          = block
        raise ArgumentError, "invalid type for filter type: #{type.class}"              unless @type.is_a?(Symbol)
        raise ArgumentError, "invalid type for attribute_type: #{attribute_type.class}" unless @attribute_type.is_a?(Symbol)
        raise ArgumentError, "invalid type for model: #{model.class}"                   unless @model.is_a?(Class)
        raise ArgumentError, "invalid type for options: #{options.class}"               unless options.is_a?(Hash)
        raise ArgumentError, "invalid filter type: #{@type}"              unless TYPES.include?(@type)
        raise ArgumentError, "invalid attribute_type: #{@attribute_type}" unless Axis::Attribute::ALIASES[@attribute_type]
        raise ArgumentError, "invalid model: #{@model.name}"              unless @model.ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "invalid options: " +
          (options.keys - OPTIONS).map { |o| o.inspect }.join(", ") unless
          (options.keys - OPTIONS).empty?
        @attribute_type = Axis::Attribute::ALIASES[@attribute_type]

        #
        # Set up our collection of "options". All entries in this hash will be
        # made available via dynamic (using #method_missing) attribute query
        # methods.
        #
        # Once initialized, process the provided options (validating them) into
        # our @options collection. This conditional processing not only
        # validates the creation of Axis::Attribute::Filter instances, but by
        # making some query methods only conditionally available (the result in
        # NoMethodError exceptions otherwise) it makes detecting erroneous
        # expectations in client code easier. For example, if a setup has an
        # attribute with a :pattern filter on it and the user calls either
        # the #blank? or #empty? attribute query methods on it, then they
        # clearly don't understand what the :pattern filter type does and so
        # these calls will raise NoMethodError exceptions, prompting the user
        # to fix their bug and misunderstanding sooner.
        #
        @options = {
          :not => !!options.delete(:not) # :not option is ALWAYS supported
        }
        case @type

        when :default
          #
          # :default filters supported on all attribute types.
          #
          # The :null option is supported and the :blank and :empty options are
          # supported if the attribute is a :string.
          #
          @options[:null] = !!options.delete(:null)
          if @attribute_type == :string
            @options[:blank] = !!options.delete(:blank)
            @options[:empty] = !!options.delete(:empty)
          end

        when :set
          #
          # :set filters supported on all but :boolean attribute types.
          #
          # This supports the :null and :multi boolean options and REQUIRES the
          # non-boolean :values option. The :values option must be set to an
          # object or array of objects (nested arrays supported) such that the
          # list contains one or more object that, once converted to a string
          # all surrounding whitespace is stripped, the resultant string
          # representation IS NOT empty. The :values option defines the list of
          # selectable values that get displayed for the user to select for the
          # value of the attribute.
          #
          # If the attribute is a :string the :blank and :empty options are also
          # supported.
          #
          raise ArgumentError, ":set filters may not be used on :boolean attributes" if @attribute_type == :boolean
          @options[:null]  = !!options.delete(:null)
          @options[:multi] = !!options.delete(:multi)
          if @attribute_type == :string
            @options[:blank] = !!options.delete(:blank)
            @options[:empty] = !!options.delete(:empty)
          end
          @options[:values] = [options.delete(:values)].flatten.map { |v| v.to_s.strip == "" ? nil : v.to_s.strip.freeze }.compact.uniq.freeze
          raise ArgumentError, ":set filters require a list of one or more :values" if @options[:values].empty?

        when :null
          #
          # :null filters supported on all attribute types.
          #
          # This supports the :multi option. If the attribute is a :string then
          # :blank and :empty are also supported. However, :blank and :empty may
          # NOT both be true at the same time!
          #
          @options[:multi] = !!options.delete(:multi)
          if @attribute_type == :string
            @options[:blank] = !!options.delete(:blank)
            @options[:empty] = !!options.delete(:empty)
            if @options[:blank] and @options[:empty]
              raise ArgumentError, ":null filters on :string attributes may not have both the :blank AND :empty options set"
            end
          end

        when :boolean
          #
          # :boolean filters supported only on :boolean attribute types.
          #
          # The :multi option is supported. However, and this is a unique
          # scenario, the :false option is only supported if :multi IS NOT set
          # (not provided or is false). So the :false option is only supported,
          # conditional on the presence/value of the :multi option.
          #
          # This means that calling #false? on a :boolean filter will raise a
          # NoMethodError (instead of just false) if called when #multi?
          # returns true.
          #
          raise ArgumentError, ":boolean filters may only be used on :boolean attributes" unless @attribute_type == :boolean
          @options[:multi] = !!options.delete(:multi)
          @options[:false] = !!options.delete(:false) unless @options[:multi]

        when :pattern
          #
          # :pattern filters supported only on :string attribute types.
          #
          # No special options supported by the :pattern filter.
          #
          raise ArgumentError, ":pattern filters may only be used on :string attributes" unless @attribute_type == :string

        else
          #
          # An unmatched filter type means a mismatch between our TYPES constant
          # and this case statement which means we've got an internal logic
          # error. If the type is invalid, it should have been caught above so
          # that we never hit this code path.
          #
          raise "internal error: unrecognized filter type: #{@type} (#{@type.class})"
        end

        #
        # Any unprocessed options, while valid in some contexts clearly aren't
        # value in the context in which they were used...
        #
        raise ArgumentError,
          "One or more options provided that aren't supported in context of the attribute\n" +
          "and filter type:\n" +
          "  Attribute Type:  #{@attribute_type}\n" +
          "  Filter Type:     #{@type}\n" +
          "  Invalid Options: " + options.keys.map { |o| o.inspect }.join(", ") unless options.empty?
        @options.freeze
      end

      attr_reader :type
      attr_reader :attribute_type
      attr_reader :model

      #
      # Since each type of filter supports different options, and since even
      # within the various types, those whose underlying attribute_type differ
      # may differ a bit in supported options, we'll dynamically implement
      # accessors for the various supported options with NoMethodError being
      # raised if you try to use an accessor that doesn't exist for the filter
      # and attribute type combination.
      #
      # For options that are "boolean", two accessors are available: one with
      # a trailing question-mark and one without. For example, both #not and
      # #not? may be called to query the value of the :not option. To see which
      # options are "boolean" see the BOOLEAN_OPTIONS constant.
      #
      def method_missing(name, *args, &block)
        if name[-1] == "?" and BOOLEAN_OPTIONS.include?(name[0..-2].intern)
          option = name[0..-2].intern
        else
          option = name.intern
        end
        if options.has_key?(option)
          options[option]
        else
          super
        end
      end

    end # class Filter

  end # class Attribute
end   # module Axis
