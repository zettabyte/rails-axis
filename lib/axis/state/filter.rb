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
        return super(method, *args, &block) unless @options.has_key?(field)
        case type
        when "=" then custom_writer(field, args.first)
        when "?" then !!@options[field]
        else        ;   @options[field]
        end
      end

      def custom_writer(field, value)
        case value
        when String then @options[field] = value.dup
        when NilClass, TrueClass, FalseClass, Numeric, Symbol, DateTime, Date, Time
          @options[field] = value
        else
          raise ArgumentError, "invalid type for filter attribute value: #{value.class}"
        end
      end

    end

  end
end
