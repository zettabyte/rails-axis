# vim: fileencoding=utf-8:
require 'meta_where'
module Axis
  class Attribute

    #
    # Simple class that represents a single entry in a potential "ORDER BY" sql
    # clause. Namely, this stores a column name and an order setting. Instances
    # are designed to be used to persist permanent configuration of
    # Axis::Attribute instances, not to be cached as state information for user
    # sessions. This distinction explains why instances are immutable and don't
    # just store an "ASCENDING" or "DESCENDING" order but instead store a more
    # complicated :ascending, :descending, :reverse, or simply true value for
    # the order information.
    #
    # In terms of Axis::Attribute configuration, an attribute may hold metadata
    # for several back-end database columns. Also, when you "sort" on said
    # attribute, you are able to define that one or more columns (optionally
    # a different set than those otherwise "included" in the attribute) are, in
    # a specific order (or arbitrary if it doesn't matter) included in the
    # resulting sql "ORDER BY" clause. For each such "sorted" column, you can
    # declare that it sort in the same order as that requested for the attribute
    # as a whole (true) or always in the reverse of the requested order
    # (:reverse), or always sort in :ascending or :descending order regardless
    # of the requested attribute order.
    #
    # This way, the state information only needs to reference an attribute name
    # on its associated model and the current, overall :ascending or :descending
    # order. Then, when constructing queries using binding and model attribute
    # metadata, which will include Axis::Attribute::Sort instances,
    #
    class Sort

      #
      # Supported Axis::Attribute::Sort types:
      #
      #   :default    => Always sort this column in the requested order
      #   :reverse    => Always sort this column in reverse of requested order
      #   :ascending  => Always sort this column in ascending order
      #   :descending => Always sort this column in descending order
      #
      TYPES = [ :default, :reverse, :ascending, :descending ].freeze

      #
      # These values (the keys) are recognized as aliases of (or equivalents to)
      # the types associated as the alias's value. The official type values are
      # included (redundant) to make unaliasing simpler.
      #
      ALIASES = {
        :default    => :default,
        :reverse    => :reverse,
        :ascending  => :ascending,
        :descending => :descending,
        true        => :default,
        :true       => :default,
        :def        => :default,
        :rev        => :reverse,
        :asc        => :ascending,
        :desc       => :descending
      }.freeze

      #
      # Create a Sort instance of the specified type on the specified column of
      # the specified model. The type must be one of the TYPES values (or one of
      # the recognized aliases in ALIASES). The column must be a string or
      # symbol that is the name of one of the columns on the corresponding
      # model. The model must be the actual model class (Class instance).
      #
      def initialize(type, column, model)
        @type   = type.is_a?(String) ? type.downcase.strip.intern : (type == true ? :true : type)
        @column = Axis.validate_column(column, model)
        @model  = model # this also validated by validate_column above
        raise ArgumentError, "invalid type for type: #{type.class}" unless @type.is_a?(Symbol)
        raise ArgumentError, "invalid type: #{@type}"               unless ALIASES[@type]
        @type = ALIASES[@type] # normalize the type
      end

      attr_reader :type
      attr_reader :model
      attr_reader :column

      #
      # If there is a request to sort an attribute in direction (dir), then this
      # will map said direction to the actual direction this associated column
      # would be sorted to. Returns a symbol, either :asc ord :desc for
      # ascending or descending respectively.
      #
      def direction(dir)
        dir = case dir.to_s
        when /\Aasc(ending)?\z/i  then :asc
        when /\Adesc(ending)?\z/i then :desc
        else ; raise ArgumentError, "illegal sorting direction: #{dir} (#{dir.class})"
        end
        case @type
        when :ascending  then :asc
        when :descending then :desc
        when :default    then dir
        when :reverse    then dir == :asc ? :desc : :asc
        else
          raise "internal error: sort instance has invalid type: #{@type} (#{type.class})"
        end
      end

      #
      # Called to apply actual sorting ("ORDER BY" clauses) on a scope over the
      # associated model. If no pre-existing scope is supplied, then this will
      # begin a new one by applying a #sort call directly against the whole
      # model class. Callers must provide the direction that it was requested
      # that it (or rather, the owning attribute) be sorted as dir.
      #
      # Returns the new scope that has this ordering applied.
      #
      # NOTE: this uses the meta_where gem's extension of the Symbol class and
      #       its extension of the ActiveRecord::QueryMethod#order method .
      #
      def order(dir, scope = nil)
        scope   ||= @model
        scope.order @column.intern.send(direction(dir))
      end

    end # class Sort

  end # class Attribute
end   # module Axis
