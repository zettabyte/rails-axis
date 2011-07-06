# encoding: utf-8
module Axis
  class Attribute
    class Filter
      class Boolean < Filter

        # Creates a :boolean-type attribute filter instance associated with an
        # attribute of the specified attribute_type on the specified model.
        def initialize(model, attribute_type, options = nil, &block)
          super # let superclass do its initialization
          options ||= {}
          @type     =  :boolean
          @radio    =  !options.delete(:checkbox) and options.delete(:radio)
          @non_true = !!options.delete(:non_true)
          raise ArgumentError, "unrecognized options present: #{options.keys.join(", ")}" unless options.empty?
        end

        # Boolean: if true a pair of radio buttons (or logical equivalent of two
        # exclusive option-selection widgets that defaults to no selection) is
        # used to select between whether to match true or false values.
        attr_reader           :radio
        alias_method :radio?, :radio

        # Boolean: if true a checkbox (or logical equivalent 2-state widget) is
        # used to select between whether to match true or false values.
        def checkbox ; !@radio end
        alias_method :checkbox?, :checkbox

        # Boolean: if true and an instance of this filter is currently selecting
        # "false" values (checkbox is unchecked or false radio button selected)
        # then, instead of explicitely matching only records where the attribute
        # is one of the "false" values, instead match all records where the
        # attribute's value ISN'T a "true" value.
        attr_reader              :non_true
        alias_method :non_true?, :non_true

      end # class  Boolean
    end   # class  Filter
  end     # class  Attribute
end       # module Axis
