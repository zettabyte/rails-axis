# encoding: utf-8
require 'axis/validate'

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

      autoload :Boolean, 'axis/attribute/filter/boolean'
      autoload :Default, 'axis/attribute/filter/default'
      autoload :Null,    'axis/attribute/filter/null'
      autoload :Pattern, 'axis/attribute/filter/pattern'
      autoload :Range,   'axis/attribute/filter/range'
      autoload :Set,     'axis/attribute/filter/set'

      # List of the supported types of Axis::Attribute::Filter instances. For
      # each type there must be a class of the same name, scoped under this
      # class (after converting the type to a string and capitalizing it, of
      # course).
      TYPES = [ :default, :set, :null, :boolean, :range, :pattern ].freeze

      # String version of TYPES to expidite comparisons (and avoid use of
      # String#intern on unknown, user-provided strings thereby eating memory)
      STYPES = TYPES.map { |type| type.to_s.freeze }.freeze

      #
      # Create an Axis::Attribute::Filter instance of the specified type that
      # references an Axis::Attribute of the specified attribute_type and that
      # is itself associated with the specified model class. Create this filter
      # using the provided (optional for some filter types) options and possibly
      # an associated code block that performs the actual filtration.
      #
      def initialize(model, attribute_type, options = nil, &block)
        raise ArgumentError, "invalid type for options: #{options.class}" unless options.nil? or options.is_a?(Hash)
        options       ||= {}
        display         = options[:display]
        negatable       = options[:negatable]
        raise ArgumentError, "invalid type for display: #{display.class}" unless display.nil? or display.is_a?(String)
        @model          = Validate.model(model)
        @attribute_type = Attribute.validate_type(attribute_type)
        @attribute_type = Attribute::ALIASES[@attribute_type] # canonical
        @negatable      = !!negatable
        @display        = display.try(:freeze)
        @block          = block
      end

      # Symbol (one of TYPES) representing this attribute filter's type.
      attr_reader :type

      # Reference to the model associated with the attribute filter. This will
      # be a Class instance for an ActiveRecord::Base-derived class.
      attr_reader :model

      # Symbol (one of Attribute::TYPES keys; normalized) indicating the data
      # type of the filter's underlying attribute.
      attr_reader :attribute_type

      # Whether or not this filter supports being "negated" (via a checkbox),
      # inverting the meaning of the filter. (boolean)
      attr_reader  :negatable
      alias_method :negatable?, :negatable

      # Optional display string. Used to display this attribute filter in lists
      # of available filters that may be applied. (may be nil)
      attr_reader             :display
      alias_method :display?, :display

      # Optional block of code that performs the actual filtering for instances
      # of this attribute filter. (may be nil)
      attr_reader           :block
      alias_method :block?, :block

      ##########################################################################
      class << self
      ##########################################################################

        #
        # Create a new attribute filter instance of the appropriate filter type.
        #
        def create(type, model, attribute_type, options = nil, &block)
          raise ArgumentError, "invalid attribute filter type: #{type} (#{type.class})" unless
            STYPES.include?(type.to_s.downcase)
          klass = "#{self.class.nesting[1]}::#{type.to_s.downcase.classify}".constantize
          klass.new(model, attribute_type, options, &block)
        end

      ##########################################################################
      end
      ##########################################################################

    end # class  Filter
  end   # class  Attribute
end     # module Axis
