# encoding: utf-8
module Axis
  class Session
    class Form

      autoload :Filter,    'axis/session/form/filter'
      autoload :FilterSet, 'axis/session/form/filter_set'

      def initialize(session, binding, state)
        @session = session
        @binding = binding
        @state   = state
      end

      attr_reader :session # the Axis::Session this form belongs to
      attr_reader :binding # this form's binding
      attr_reader :state   # this form's state
      attr_reader :records # array (or proxy object) containing page of records
      attr_reader :record  # cached instance of currently selected record

      #
      # Expects a block which will be saved and used on any subsequent calls to
      # #render_field (above) to actually render any field for a given
      # attribute. The provided block should expect three parameters: the
      # associated Axis::Attribute instance (1), the current ActiveRecord
      # instance (2), and the default-rendered value for the attribute.
      #
      # If, for a given call, the block doesn't return a string, then the
      # default-rendered value (that's passed as the third parameter to the
      # block) will be used. Otherwise the returned string will be used instead.
      #
      attr_accessor :table_formatter

      #
      # The following just provide proxied-access to the associated members on
      # the form's binding.
      #
      def id     ; binding.id     end
      def model  ; binding.model  end
      def scope  ; binding.scope  end
      def type   ; binding.type   end
      def handle ; binding.handle end

      #
      # Used to generate the id string, used in HTML elements (and referenced by
      # CSS rules), for a given attribute. The attribute here is defined by a
      # list of values that hierarchically define the attribute. This would be
      # the same set of keys as passed to the #attr_name method, but we're
      # instead generating an HTML id which is used on any/all elements, not
      # just form controls. If no keys are specified, then the HTML id of the
      # form itself is returned.
      #
      # Examples:
      #   form.attr_id                      => "axis-2"
      #   form.attr_id("filter", 3, "type") => "axis-2-filter-3-type"
      #
      def attr_id(*keys)
        session.attr_id(*keys.unshift(id))
      end

      #
      # Used to generate the name, used in HTML form controls, for a given
      # attribute. The attribute here is defined by a list of values that would
      # be the sequence of keys needed to look up the attribute value in the
      # resulting params hash.
      #
      # Example:
      #   form.attr_name("filter", 3, "type") => "axis[2][filter][3][type]"
      #
      def attr_name(*keys)
        session.attr_name(*keys.unshift(id))
      end

      #
      # Used to generate a hash which may be provided to URL-constructing
      # helpers in order to create a query-string key and value that, when it is
      # processed in a future request, will yield a params hash entry that needs
      # the same chain (hierarchy) of keys to access the provided value.
      #
      # The last parameter is considered the value and all other parameters are
      # considered part of the key chain.
      #
      # Example:
      #   form.attr_hash("del", 3)
      #     => { "axis" => { 2 => { "del" => 3 } } }
      #     => "axis[2][del]=3"       # (after helper converts to query string)
      #   params["axis"]["2"]["del"]  # on next request after user clicks link
      #     => "3"
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
        session.attr_hash(*keys_and_value.unshift(id))
      end

      #
      # Render the attribute (assume it's one of our displayable ones) for the
      # provided record. Uses any configured table formatting block (as provided
      # by a call to #with_table_formatter) if present, otherwise just uses the
      # default-rendered value.
      #
      def render_field(attr, record)
        default   = attr.render(record)
        formatted = table_formatter.call(attr, record, default) if table_formatter
        formatted.is_a?(String) ? formatted : default
      end

      #
      # Only display, sort, or filter by the named attributes and, when showing
      # columns, use this ordering...
      #
      def mask_and_order_by(*names)
        @attributes_mask  = names.flatten
        @attributes_order = @attributes_mask
        self
      end

      #
      # Returns an array listing the names of the available filters. More
      # specifically, the elements in the array are themselves two-element
      # arrays with the first being the human friendly name of a filter and the
      # last element the searchable attribute's name.
      #
      # This is intended to be usable by callers who want to use one of the
      # rails view helpers to construct an HTML options list.
      #
      def available_filters
        searchables.map { |name, attr| [attr.display, name] }
      end

      #
      # Returns reference to this form's parent-form (if any)
      #
      def parent
        return nil unless binding.parent
        @parent ||= @session.forms[binding.parent.id]
      end

      #
      # Returns an array of references to this form's child forms (or sub-forms)
      #
      # NOTE: Lack of caching here deliberate; forms created in controller pre-
      #       filter and if a parent form called this before child forms were
      #       created by this process, an incomplete result would be cached. So,
      #       also beware of this that _you_ don't call this till the before
      #       filter is done.
      #
      def children
        binding.children.map { |b| @session.forms[b.id] }.compact
      end

      #
      # Returns all the attributes associated with the model this form is bound
      # to as a hash keyed by the attribute name.
      #
      def attributes
        @attributes ||= Attribute[model]
      end

      #
      # Returns a subset of #attributes, including only those marked displayable
      #
      def displayables
        @displayables ||= attributes.reject { |k, v| !v.displayable? }
      end

      #
      # Returns a subset of #attributes, including only those marked searchable
      #
      def searchables
        @searchables ||= attributes.reject { |k, v| !v.searchable? }
      end

      #
      # Returns a subset of #attributes, including only those marked sortable
      #
      def sortables
        @sortables ||= attributes.reject { |k, v| !v.sortable? }
      end

      #
      # The following just provide proxied-access to the associated members on
      # the form's state.
      #
      def per         ; state.per         end
      def page        ; state.page        end
      def pages       ; state.pages       end
      def selected    ; state.selected    end
      def total       ; state.total       end
      def offset      ; state.offset      end
      def page_offset ; state.page_offset end

      #
      # This returns the absolute total number of records available (the number
      # this form is bound to when no filters are applied).
      #
      def absolute_total
        if parent
          parent.record.send(scope).count
        else
          model.send(scope || :all).count
        end
      end

      #
      # This updates the total (as stored in the state) according to how many
      # records match our filters. This new, updated total is then returned.
      #
      def update_total
        state.total = scoped.count
      end

      #
      # This will use the current set of filters and pagination information to
      # load the current page of record.
      #
      # NOTE: If no page is selected but there is at least one matching record
      #       then page 1 will be selected and the first record of the page will
      #       be chosen.
      #
      def reload!
        update_total
        if state.total > 0
          state.page = 1 if page < 1
          @records = paged
          @record  = @records[selected - 1]
        else
          @records = []  # none in current page
          @record  = nil # no record selected
        end
      end

      #
      # Returns a scope on the bound set of records with *NO* filters applied!
      # Thus, this will include all (related) records that the raw, bound scope
      # has access to. Use #filtered to get a scope with the filters already
      # applied.
      #
      def scoped
        if parent
          parent.record.send(scope)
        else
          scope ? model.send(scope) : model
        end
      end

      #
      # Returns a scope on the bound set of records that has been narrowed by
      # applying any/all filters. This should be used to actually access records
      # for the form.
      #
      def filtered
        filters.inject(scoped) { |scope, filter| filter.apply(scope) }
      end

      #
      # Returns a filtered scope (using #filtered), limiting the scope to the
      # current page of records.
      #
      def paged
        filtered.offset(page_offset).limit(per)
      end

      #
      # Provide access to the current form's filters (as Session::Form::Filter
      # instances wrapping State::Filter instances and their associated
      # Attribute and Attribute::Fitler instances).
      #
      # The filters are held in an array-like object, an instance of FilterSet.
      #
      def filters
        @filters ||= FilterSet.new(self)
      end

      #
      # Update this form's state according to the provided options (from the
      # request's params hash) and the specified command (value of the 'commit'
      # key if present).
      #
      # Returns the form object, making this method chainable.
      #
      def update(options, command = nil)
        unless options.is_a?(Hash)
          # Support simple "reset" links
          state.reset if options =~ /^reset$/i
          # See if shorthand offset record selection was used...
          i = Normalize.integer(options)
          if i.is_a?(Integer)
            state.offset = i rescue nil
          end
        end

        #
        # At this point, all other actions will be represented by options being
        # a hash. So, if it isn't a hash, make it one...
        #
        options = {} unless options.is_a?(Hash)

        #
        # See if there was a request to nuke a filter
        #
        if options[:del]
          i = Validate.integer(options[:del], 0) rescue nil
          if options[:del] == "all"
            filters.reset
          elsif i and i < filters.length
            filters.delete_at(i)
          end
        end

        #
        # See if there was a request to add a filter
        #
        if options[:add]
          attribute = searchables[options[:add]]
          filters.add(attribute) if attribute
        end

        #
        # See if the search form was submitted. If so, take the action appropriate
        # to the commit "command".
        #
        if options[:form] == "search"
          if command =~ /^update$/i
            filters_changed = false
            changes         = options[:filter].is_a?(Hash) ? options[:filter] : {}
            filters.each_with_index do |filter, filter_id|
              filters_changed = filter.update(changes[filter_id.to_s]) ? true : filters_changed
            end
            state.reset_selection if filters_changed
          elsif command =~ /^reset$/i
            filters.reset unless filters.empty?
          end
        end

        # 2. check for sort-clause updates
        #   a. modify active sort commands: axis[0][sort]=reset, =desc, =asc, =rev
        #   b. specific sort commands: ={:by => attr_name [, :dir => one of: :asc, :desc]}
        # 3. check for page selection/navigation
        #   a. page selection: axis[0][page]=5 / axis[0][page]=first, =last, :next, :prev, :none, :reset
        # 4. check for record selection
        #   a. record selection: axis[0][select]=2 / axis[0][select]=first, =last, :next, :prev, :none, :reset
        #   b. offset selection: axis[0][offset]=0

        reload! # apply filters and get current page
        self
      end

    end
  end
end
