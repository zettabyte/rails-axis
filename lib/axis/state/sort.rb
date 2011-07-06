# encoding: utf-8
module Axis
  class State

    #
    # Instances represent an sorting preference to be stored in a State object.
    #
    class Sort

      def initialize(name, descending = false)
        @name = name.to_s.freeze
        @desc = !!descending
      end

      # Associated attribute name (literal or logical)
      attr_reader :name

      # True if requested sort direction is "descending"
      attr_reader :desc

      # True if requested sort direction is "ascending"
      def asc ; !@desc end

      alias_method :desc?, :desc
      alias_method :asc?,  :asc

      # Set the sort direction to "descending" if provided direction is true.
      # Sets the direction to "ascending" otherwise.
      def desc=(dir) ; @desc = !!dir end

      # Set the sort direction to "ascending" if provided direction is true.
      # Sets the direction to "descending" otherwise.
      def asc=(dir) ; @desc = !dir end

      # Set the sort direction to "descending"
      def desc! ; @desc = true ; self end

      # Set the sort direction to "ascending"
      def asc! ; @desc = false ; self end

      def ==(other)
        @name == other.name && @desc == other.desc
      end

    end # class  Sort
  end   # class  State
end     # module Axis
