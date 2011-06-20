# encoding: utf-8
module Axis
  class State

    #
    # Represents an individual record-filtration clause to be stored in a state
    # object.
    #
    class Filter

      DEFAULT_TYPES = [
        { :value => :equal,   :string   => "Matches".freeze, :numeric => "=".freeze, :temporal => "Equal To".freeze }.freeze,
        { :value => :begin,   :string   => "Starts With".freeze                        }.freeze,
        { :value => :less,    :numeric  => "<".freeze                                  }.freeze,
        { :value => :before,  :temporal => "Before".freeze                             }.freeze,
        { :value => :end,     :string   => "Ends With".freeze                          }.freeze,
        { :value => :greater, :numeric  => ">".freeze                                  }.freeze,
        { :value => :after,   :temporal => "After".freeze                              }.freeze,
        { :value => :le,      :numeric  => "<=".freeze                                 }.freeze,
        { :value => :beon,    :temporal => "Before or On".freeze                       }.freeze,
        { :value => :ge,      :numeric  => ">=".freeze                                 }.freeze,
        { :value => :afon,    :temporal => "After or On".freeze                        }.freeze,
        { :value => :match,   :string   => "Contains".freeze                           }.freeze,
        { :value => :true,    :boolean  => "True".freeze                               }.freeze,
        { :value => :false,   :boolean  => "False".freeze                              }.freeze,
        { :value => :blank,   :string   => "Is Blank".freeze                           }.freeze,
        { :value => :unset,   :string   => "Is Unset".freeze, :all => "[Unset]".freeze }.freeze,
        { :value => :empty,   :string   => "Is Empty".freeze                           }.freeze
      ]

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

      ##########################################################################
      class << self
      ##########################################################################

        def default_type_options(type)
          legal = %w{ string numeric temporal boolean }
          raise ArgumentError, "invalid type for type: #{type.class}" unless type.is_a?(String) or type.is_a?(Symbol)
          raise ArgumentError, "invalid value for type: #{type}"      unless legal.include?(type.to_s)
          type = type.intern
          DEFAULT_TYPES.reject do |t|
            t[type].nil? and t[:all].nil?
          end.map do |t|
            [t[type] || t[:all], t[:value].to_s]
          end
        end

      ##########################################################################
      end
      ##########################################################################

    end # class Filter
  end   # class State
end     # module Axis
