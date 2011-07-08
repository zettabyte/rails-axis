# encoding: utf-8
module Axis
  class Session
    class Form
      class SortSet

        include Enumerable

        def initialize(form)
          @form = form
        end

        #
        # The form this sort set is associated with.
        #
        attr_reader :form

        #
        # Get access to the underlying array access to which we're wrapping
        #
        def array
          form.state.sort
        end

        def length  ; array.length                        end
        def to_a    ; array.map { |s| Sort.new(form, s) } end
        def to_s    ; to_a.to_s                           end
        def inspect ; to_a.inspect                        end

        def each(&block)
          to_a.each(&block)
        end

        def ==(other)
          return false unless other.is_a?(SortSet)
          form == other.form
        end

        def <=>(other)
          return -1 unless other.is_a?(SortSet)
          form == other.form ? 0 : 1
        end

        def [](*args)
          if args.length == 1 and args.first.is_a?(Axis::Attribute)
            args = [array.index { |state| args.first.name == state.name }].compact
            return nil if args.empty?
          end
          to_a.send(:[], *args)
        end

        def empty?
          array.empty?
        end

        def delete_at(index)
          index  = Validate.integer(index, 0)
          result = array.delete_at(index)
          form.state.reset_sort if result
          result ? Sort.new(form, result) : nil # be consistent
        end

        def index(obj)
          array.index do |state|
             obj                         == state ||
            (obj.try(:state) rescue nil) == state ||
            (obj.try(:name)  rescue nil) == state.name
          end
        end

        #
        # Nuke all the sort instances on the form...
        #
        def reset
          form.state.reset_sort
          self # this method is chainable
        end

        #
        # Add a new sort instance to the form (with the provided direction as
        # the new or default direction).
        #
        def add(attribute, descending = false)
          raise ArgumentError, "provided attribute isn't sortable: #{attribute.name}" unless attribute.sortable?
          array << Axis::State::Sort.new(attribute.name, descending)
          self # this method is chainable
        end

      end # class  FilterSet
    end   # class  Form
  end     # class  Session
end       # module Axis
