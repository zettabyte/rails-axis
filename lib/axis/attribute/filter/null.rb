# encoding: utf-8
module Axis
  class Attribute
    class Filter
      class Null < Filter

        # Creates a :null-type attribute filter instance associated with an
        # attribute of the specified attribute_type on the specified model.
        def initialize(model, attribute_type, options = nil, &block)
          super # let superclass do its initialization
          options  ||= {}
          @type      = :null
          @radio     = !options.delete(:checkbox) and options.delete(:radio)
          @use_blank =  options.delete(:blank)    and attribute_type == :string
          @use_empty =  options.delete(:empty)    and attribute_type == :string
          raise ArgumentError, "cannot specify :blank and :empty options together" if @use_blank and @use_empty
          raise ArgumentError, "unrecognized options present: #{options.keys.join(", ")}" unless options.empty?
        end

        # Boolean: if true a pair of radio buttons (or logical equivalent of two
        # exclusive option-selection widgets that defaults to no selection) is
        # used to select between whether to match NULL or non-NULL values.
        attr_reader           :radio
        alias_method :radio?, :radio

        # Boolean: if true a checkbox (or logical equivalent 2-state widget) is
        # used to select between whether to match NULL or non-NULL values.
        def checkbox ; !@radio end
        alias_method :checkbox?, :checkbox

        # (=> *) Boolean: if true then, when the checkbox is checked or the NULL
        # option radio button is selected, instead of matching just NULL values
        # match NULL values an all "empty" strings ("" or all-whitespace).
        attr_reader               :use_blank
        alias_method :use_blank?, :use_blank

        # (=> *) Boolean: if true then, when the checkbox is checked or the NULL
        # option radio button is selected, instead of matching NULL values match
        # "empty" strings ("" or all-whitespace).
        attr_reader               :use_empty
        alias_method :use_empty?, :use_empty

      end # class  Null
    end   # class  Filter
  end     # class  Attribute
end       # module Axis
