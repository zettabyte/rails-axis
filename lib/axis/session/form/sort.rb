# encoding: utf-8
require 'axis/validate'

module Axis
  class Session
    class Form

      #
      # A session or form sort is a glue or composite object that joins an
      # attribute to a specific state sort instance. Thus, it represents an
      # actual sort clause, complete both with meta-data (from the attribute and
      # the attribute sort information) and state information (from the state
      # sort).
      #
      class Sort

        PARAMS = "sort".freeze

        #
        # Create a form sort which is a logic-rich wrapper around an attribute
        # (and its attribute sort data) and a state sort instance. You must
        # provide the form this form-sort applies to and the associated state
        # sort.
        #
        def initialize(form, state)
          @form      = form                       # containing form
          @state     = state                      # this is the state sort
          @attribute = form.sortables[state.name] # associated attribute
          raise ArgumentError, "invalid state sort; it's name doesn't match " +
            "any sortable attribute: #{state.name}" unless @attribute
        end

        #
        # Returns the current current "id" for this form sort, which is the
        # array index of the associated state sort inside the current collection
        # of the user's sorts for the session.
        #
        def id
          form.sorts.index(state)
        end

        #
        # Returns the current "priority" for this form sort. This is always just
        # the #id plus one.
        #
        def priority
          id + 1
        end

        attr_reader :form      # containing form
        attr_reader :state     # state sort instance
        attr_reader :attribute # associated attribute

        #
        # Used to generate the id string, used in HTML elements (and referenced
        # by CSS rules), for a given attribute associated with this sort. The
        # attribute here is defined by a list of values that hierarchically
        # define the attribute. This would be the same set of keys as passed to
        # the #attr_name method, but we're instead generating an HTML id which
        # is used on any/all elements, not just form controls. If no keys are
        # specified, then the HTML id of the sort itself is returned.
        #
        # Examples:
        #   sort.attr_id              => "axis-2-sort-3"
        #   sort.attr_id("direction") => "axis-2-sort-3-direction"
        #
        def attr_id(*keys)
          form.attr_id(*keys.unshift(PARAMS.dup, id))
        end

        #
        # Used to generate the name, used in HTML form controls, for a given
        # attribute associated with this sort. The attribute here is defined by
        # a list of values that would be the sequence of keys needed to look up
        # up the attribute value in the resulting params hash.
        #
        # Example:
        #   sort.attr_name("direction") => "axis[2][sort][3][direction]"
        #
        def attr_name(*keys)
          form.attr_name(*keys.unshift(PARAMS.dup, id))
        end

        #
        # Used to generate a hash which may be provided to URL-constructing
        # helpers in order to create a query-string key and value that, when it
        # is processed in a future request, will yield a params hash entry that
        # needs the same chain (hierarchy) of keys to access the provided value.
        #
        # The last parameter is considered the value and all other parameters
        # are considered part of the key chain.
        #
        # Example:
        #   sort.attr_hash("direction", "asc")
        #     => { "axis" => { 2 => { "sort" => { 3 => { "direction" => "asc" } } } } }
        #     => "axis[2][sort][3][direction]=asc" # after helper converts to querystring
        #   params["axis"]["2"]["sort"]["3"]["direction"] # next request after user clicks link
        #     => "asc"
        #
        # If the last parameter is a hash, then instead of being considered the
        # value it will be considered a "merge" hash and the second-to-the-last
        # parameter will be considered the value. If a "merge" hash is present,
        # then the hash this method normally constructs will be merged with the
        # provided "merge" hash and the result of the merge returned.
        #
        # The merge will favor values in the new hash this method generates over
        # values in the "merge" if there is any conflict.
        #
        def attr_hash(*keys_and_value)
          form.attr_hash(*keys_and_value.unshift(PARAMS.dup, id))
        end

        #
        # Used to generate the class string, used in HTML elements (and
        # referenced by CSS rules), for a given attribute's column header cell
        # that takes into account the sorting state currently in effect. The
        # caller must provide the prefix keys (sans the global axis class prefix
        # key) for the desired class name.
        #
        # Examples:
        #   form.attr_class("table", "header") => "axis-table-header-sorting-2-up"
        #
        def attr_class(*prefix)
          keys = prefix.flatten + ["sorting", priority.to_s]
          unless unidirectional?
            # we can sort different directions on this attribute
            keys << (asc? ? "asc" : "desc")
          end
          form.attr_class(*keys)
        end

        def unidirectional?
          attribute.unidirectional?
        end

        #
        # Attempts to reverse the direction of this sort. Returns true if
        # successful.
        #
        def reverse
          return false if unidirectional?
          state.desc = !state.desc?
          true
        end

        #
        # Apply this sort item to the provided scope and return said scope.
        #
        def apply(scope)
          direction = asc? ? :asc : :desc
          attribute.sort.reduce(scope) do |result, entry|
            dir = case entry.type
            when :ascending  then :asc
            when :descending then :desc
            when :default    then direction
            when :reverse    then direction == :asc ? :desc : :asc
            end
            result.order entry.column.intern.send(dir)
          end
        end

        ########################################################################
        private
        ########################################################################

        #
        # Proxy all method calls we don't respond to to the state sort instance.
        #
        def method_missing(name, *args, &block)
          begin ; return @state.send(name, *args, &block) ; rescue NoMethodError ; end
          super
        end

      end # class  Sort
    end   # class  Form
  end     # class  Session
end       # module Axis
