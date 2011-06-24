# encoding: utf-8
module Axis
  class State

    #
    # Represents an individual record-filtration clause to be stored in a state
    # object.
    #
    class Filter

      def initialize(name, options = nil)
        raise ArgumentError, "invalid type for options: #{options.class}" unless options.nil? or options.is_a?(Hash)
        @name    = name.to_s.freeze
        @options = options ? options.deep_clone : {}
      end

      attr_reader :name # associated attribute name (literal or logical)
      attr_reader :options

      private

      def method_missing(method, *args, &block)
        field = method.to_s
        return super(method, *args, &block) unless field =~ /\A(\w+)(=|\?)?\z/
        field = $1
        type  = $2
        return super(method, *args, &block) unless @options.has_key?(field) or type == "="
        case type
        when "=" then custom_writer(field, args.first)
        when "?" then !!@options[field]
        else        ;   @options[field]
        end
      end

      def custom_writer(field, value)
        @options[field] = validate_value(value)
      end

      def validate_value(value, allow_array = true)
        case value
        when NilClass, TrueClass, FalseClass then value
        when Numeric                         then value
        when Symbol                          then value
        when String                          then value.dup
        when DateTime, Date, Time            then value
        else
          raise ArgumentError, "invalid type for filter attribute value: #{value.class}" unless value.is_a?(Array) and allow_array
          value.map { |v| validate_value(v, false) }
        end
      end

    end # class Filter
  end   # class State
end     # module Axis
