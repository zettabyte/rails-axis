# encoding: utf-8
module Axis
  class Attribute
    class Filter
      class Set < Filter

        # Creates a :set-type attribute filter instance associated with an
        # attribute of the specified attribute_type on the specified model.
        def initialize(model, attribute_type, options = nil, &block)
          super # let superclass do its initialization
          options      ||= {}
          @type          =  :set
          @multiple      = !!options.delete(:multi)
          @include_null  = !!options.delete(:null)
          @include_empty = !!options.delete(:empty) and attribute_type == :string
          @include_blank = !!options.delete(:blank) and attribute_type == :string
          @values        =   options.delete(:values)
          if @values.is_a?(Array)
            @ordering = @values # ordering just becomes alias for values
          elsif @values.is_a?(Hash)
            @ordering = @values.keys # whatever order the hash yields array of keys is order
            @values.freeze           # must manually freeze @values since @ordering isn't an alias for it
          else
            raise ArgumentError, "invalid type for :values option: #{@values.class}"
          end
          @ordering.freeze
          raise ArgumentError, "unrecognized options present: #{options.keys.join(", ")}" unless options.empty?
        end

        # Boolean: if true, allow the user to select any number of the available
        # options (determined by the #values field). Multiple selections mean
        # that a record may match if the attribute matches ANY of the selected
        # values.
        attr_reader  :multiple
        alias_method :multiple?, :multiple

        # Boolean: if true, include as an option the ability to explicitely
        # select a choice to match all records where the associated attribute is
        # NULL.
        attr_reader                  :include_null
        alias_method :include_null?, :include_null

        # Boolean: if true, include as an option the ability to explicitely
        # select a choice to match all records where the associated attribute is
        # an "empty" string ("").
        attr_reader                   :include_empty
        alias_method :include_empty?, :include_empty

        # Boolean: if true, include as an option the ability to explicitely
        # select a choice to match all records where the associated attribute is
        # either NULL or an "empty" string ("").
        attr_reader                   :include_blank
        alias_method :include_blank?, :include_blank

        # Hash or Array containing the values that a user may select in order to
        # have matched against the record's associated attribute. If it is an
        # array then the value will be displayed to the user using the object's
        # #to_s method. The object type should match or be appropriate for the
        # attribute_type. If it is a hash then the keys should be strings that
        # will be displayed to represent the value while the hash value will be
        # the actual value matched against the attribute.
        attr_reader :values

        # Array that contains the value keys (may just be an alias for #values)
        # of the #values Hash or Array in the static order in which they'll be
        # displayed to the user in the UI
        attr_reader :ordering

      end # class  Set
    end   # class  Filter
  end     # class  Attribute
end       # module Axis
