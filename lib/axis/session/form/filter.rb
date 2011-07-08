# encoding: utf-8
require 'axis/validate'

module Axis
  class Session
    class Form

      #
      # A session or form filter is a glue or composite object that joins an
      # attribute filter instance to a specific state filter instance. Thus, it
      # represents and actual filter, complete both with meta-data (from the
      # attribute and the attribute filter) and state information (from the
      # state filter).
      #
      class Filter

        autoload :Boolean, 'axis/session/form/filter/boolean'
        autoload :Default, 'axis/session/form/filter/default'
        autoload :Null,    'axis/session/form/filter/null'
        autoload :Pattern, 'axis/session/form/filter/pattern'
        autoload :Range,   'axis/session/form/filter/range'
        autoload :Set,     'axis/session/form/filter/set'

        # Sub-hash key for filters in params.
        PARAMS = "filter".freeze

        ########################################################################
        class << self
        ########################################################################

          #
          # Create a wrapping "form" filter using the provided form instance and
          # the selected "state" filter of the appropriate filter sub-type.
          #
          def create(form, state)
            klass = state.class.name.gsub(/.*::/, "#{self.class.nesting[1]}::").constantize
            klass.new(form, state)
          end

        ########################################################################
        end
        ########################################################################

        #
        # Create a form filter which is a logic-rich wrapper around an attribute
        # (and its attribute filter) and a state filter instance. You must
        # the form this form-filter applies to and the associated state filter.
        #
        def initialize(form, state)
          @form      = form                         # containing form
          @state     = state                        # this is the state filter
          @attribute = form.searchables[state.name] # associated attribute
          raise ArgumentError, "invalid state filter; it's name doesn't match " +
            "any searchable attribute: #{state.name}" unless @attribute
        end

        #
        # Returns the current current "id" for this filter, which is the array
        # index of the associated state filter inside the current collection of
        # the user's filters for the session.
        #
        def id
          form.filters.index(state)
        end

        attr_reader :form      # containing form
        attr_reader :state     # state filter instance
        attr_reader :attribute # associated ttribute

        #
        # Used to generate the id string, used in HTML elements (and referenced
        # by CSS rules), for a given attribute associated with this filter. The
        # attribute here is defined by a list of values that hierarchically
        # define the attribute. This would be the same set of keys as passed to
        # the #attr_name method, but we're instead generating an HTML id which
        # is used on any/all elements, not just form controls. If no keys are
        # specified, then the HTML id of the filter itself is returned.
        #
        # Examples:
        #   filter.attr_id         => "axis-2-filter-3"
        #   filter.attr_id("type") => "axis-2-filter-3-type"
        #
        def attr_id(*keys)
          form.attr_id(*keys.unshift(PARAMS.dup, id))
        end

        #
        # Used to generate the name, used in HTML form controls, for a given
        # attribute associated with this filter. The attribute here is defined
        # by a list of values that would be the sequence of keys needed to look
        # up the attribute value in the resulting params hash.
        #
        # Example:
        #   filter.attr_name("type") => "axis[2][filter][3][type]"
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
        #   filter.attr_hash("type", "equal")
        #     => { "axis" => { 2 => { "filter" => { "type" => "equal" } } } }
        #     => "axis[2][filter]=equal"  # after helper converts to querystring
        #   params["axis"]["2"]["filter"] # next request after user clicks link
        #     => "equal"
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
        # Retrieve the display name of the attribute this filter operates on
        #
        def display
          attribute.display
        end

        #
        # Apply this filter to the provided scope.
        #
        def apply(scope)
          return scope unless apply?
          # Use logical filter's custom block if one exists...
          return block.call(scope, self) if block?
          # Generate our composite where-clause condition hash (well, a
          # MetaWhere::Compound wrapper for potentially several hashes).
          conditions = attribute.columns.map do |column|
            # Generate where clause condition hash for this column...
            where_clause(column)
          end.compact.reduce do |result, condition|
            # Combine generated where clause condition hashes together using
            # a logical (SQL) OR-ing of them (unless negated in which case we
            # should AND them)...
            negated? ? (result & condition) : (result | condition)
          end
          # If none of our conditions applied, return scope unaltered,
          # otherwise return sub-scope after applying our conditions...
          conditions ? scope.where(conditions) : scope
        end

        #
        # Update the form's filter according to the provided "changes". Returns
        # a boolean indicating whether any changes were made or not.
        #
        def update(changes = nil)
          changes ||= {}
          result    = private_update(changes) # perform type-specific updates
          negate    = Validate.boolean(changes[:negate]) rescue nil
          if negatable?
            result      ||= negate != negated?
            self.negated  = negate
          end
          result
        end

        ########################################################################
        private
        ########################################################################

        #
        # Proxy all method calls we don't respond to first to the attribute
        # filter instance and then to the state filter instance.
        #
        def method_missing(name, *args, &block)
          begin ; return @attribute.filter.send(name, *args, &block) ; rescue NoMethodError ; end
          begin ; return @state.send(name, *args, &block)            ; rescue NoMethodError ; end
          super
        end

      end # class  Filter
    end   # class  Form
  end     # class  Session
end       # module Axis
