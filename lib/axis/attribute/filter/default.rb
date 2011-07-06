# encoding: utf-8
module Axis
  class Attribute
    class Filter
      class Default < Filter

        # Creates a :default-type attribute filter instance associated with an
        # attribute of the specified attribute_type on the specified model.
        def initialize(model, attribute_type, options = nil, &block)
          super # let superclass do its initialization
          options      ||= {}
          @type          =  :default
          @include_null  = !!options.delete(:null)
          @include_blank = !!options.delete(:blank) and attribute_type == :string
          @include_empty = !!options.delete(:empty) and attribute_type == :string
          raise ArgumentError, "unrecognized options present: #{options.keys.join(", ")}" unless options.empty?
        end

        # Boolean: if true, include as an option the ability to explicitely
        # select a choice to match all records where the associated attribute is
        # NULL.
        attr_reader                  :include_null
        alias_method :include_null?, :include_null

        # Boolean: if true, include as an option the ability to explicitely
        # select a choice to match all records where the associated attribute is
        # either NULL or an "empty" string ("" or a whitespace only string).
        attr_reader                   :include_blank
        alias_method :include_blank?, :include_blank

        # Boolean: if true, include as an option the ability to explicitely
        # select a choice to match all records where the associated attribute is
        # an "empty" string ("" or a whitespace only string).
        attr_reader                   :include_empty
        alias_method :include_empty?, :include_empty

      end # class  Default
    end   # class  Filter
  end     # class  Attribute
end       # module Axis
