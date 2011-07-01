# encoding: utf-8
module Axis
  class State

    #
    # Represents an individual record-filtration clause to be stored in a state
    # object. Don't create instances of this class directly, instead use on of
    # the subclasses that are namespaced below this class (and stored in the
    # "./filter" sub-directory).
    #
    class Filter

      autoload :Boolean, 'axis/state/filter/boolean'
      autoload :Default, 'axis/state/filter/default'
      autoload :Null,    'axis/state/filter/null'
      autoload :Pattern, 'axis/state/filter/pattern'
      autoload :Range,   'axis/state/filter/range'
      autoload :Set,     'axis/state/filter/set'

      def initialize(name)
        @name    = name.to_s.freeze
        @negated = false
      end

      # Name of model's attribute associated with this filter.
      attr_reader :name

      # If true, the meaning of this filter is negated as a whole.
      attr_accessor           :negated
      alias_method :negated?, :negated

      ##########################################################################
      class << self
      ##########################################################################

        #
        # Create a new instance of one of the Filter class's sub-classes and
        # return it.
        #
        def create(name, filter)
          klass = "#{self.class.nesting[1]}::#{filter.type.to_s.classify}".constantize
          klass.new(name)
        end

      ##########################################################################
      end
      ##########################################################################

    end # class  Filter
  end   # class  State
end     # module Axis
