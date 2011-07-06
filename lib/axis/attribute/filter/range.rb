# encoding: utf-8
module Axis
  class Attribute
    class Filter
      class Range < Filter

        # Creates a :range-type attribute filter instance associated with an
        # attribute of the specified attribute_type on the specified model.
        def initialize(model, attribute_type, options = nil, &block)
          super # let superclass do its initialization
          @type = :range
          raise ArgumentError, "unrecognized options present: #{options.keys.join(", ")}" if options and !options.empty?
        end

      end # class  Range
    end   # class  Filter
  end     # class  Attribute
end       # module Axis
