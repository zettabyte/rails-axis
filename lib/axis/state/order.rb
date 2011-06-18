# encoding: utf-8
module Axis
  class State

    #
    # Instances represent an ordering preference to be stored in a State object.
    #
    class Order
      def initialize(name, descending = false)
        @name = name.to_s.freeze
        @desc = !!descending
      end
      attr_reader  :name # associated attribute name (literal or logical)
      attr_reader  :desc # true if requested sort direction is "descending"
      def asc        ; !@desc                end
      def desc=(dir) ;  @desc = !!dir        end
      def asc=(dir)  ;  @desc =  !dir        end
      def desc!      ;  @desc = true  ; self end
      def asc!       ;  @desc = false ; self end
      alias_method :desc?, :desc
      alias_method :asc?,  :asc
      def ==(other)
        @name == other.name && @desc == other.desc
      end
    end

  end
end
