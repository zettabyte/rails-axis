# encoding: utf-8
module Axis
  class Session
    class Form
      class FilterSet

        include Enumerable

        def initialize(form)
          @form = form
        end

        #
        # The form this filter set is associated with.
        #
        attr_reader :form

        #
        # Get access to the underlying array access to which we're wrapping
        #
        def array
          form.state.filters
        end

        def length  ; array.length                          end
        def to_a    ; array.map { |f| Filter.new(form, f) } end
        def to_s    ; to_a.to_s                             end
        def inspect ; to_a.inspect                          end

        def each(&block)
          to_a.each(&block)
        end

        def ==(other)
          return false unless other.is_a?(FilterSet)
          form == other.form
        end

        def <=>(other)
          return -1 unless other.is_a?(FilterSet)
          form == other.form ? 0 : 1
        end

        def [](*args)
          to_a.send(:[], *args)
        end

        def delete_at(index)
          result = array.delete_at(index)
          form.state.reset_selection if result
          result ? Filter.new(form, f) : nil # be consistent
        end

        #
        # Nuke all the filters on the form...
        #
        def reset
          form.state.reset_filters
          self # this method is chainable
        end

        #
        # Add a new filter to the form: Axis::Session::Form::Filter.create
        # actually returns an Axis::State::Filter instance. This is just to keep
        # code concerned with defaults in the same place (the State hierarchy of
        # classes should be kept dumb).
        #
        def add(attribute)
          array << Filter.create(form, attribute)
          self # this method is chainable
        end

      end # class  FilterSet
    end   # class  Form
  end     # class  Session
end       # module Axis