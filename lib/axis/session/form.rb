# encoding: utf-8
module Axis
  class Session
    class Form

      autoload :Filter,    'axis/session/form/filter'
      autoload :FilterSet, 'axis/session/form/filter_set'
      autoload :Sort,      'axis/session/form/sort'
      autoload :SortSet,   'axis/session/form/sort_set'

      SETTINGS = {
        :minimum_in_group     => 9, # may never be set below 1
        :minimum_at_beginning => 2, # must be >= 0
        :minimum_at_end       => 2, # must be >= 0
        :include_first        => true,
        :include_rewind       => true,
        :include_prev         => true,
        :include_next         => true,
        :include_forward      => true,
        :include_last         => true,
        :always_show_first    => true,
        :always_show_rewind   => true,
        :always_show_prev     => true,
        :always_show_next     => true,
        :always_show_forward  => true,
        :always_show_last     => true,
        :label_first          => "First".freeze,
        :label_rewind         => "&#x27ea;".freeze,
        :label_prev           => "&#x27e8;".freeze,
        :label_next           => "&#x27e9;".freeze,
        :label_forward        => "&#x27eb;".freeze,
        :label_last           => "Last".freeze,
        :label_ellipses       => "&hellip;".freeze
      }.freeze

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
      # Just a proxy pass-through to the #attr_class method on the underlying
      # Axis::Session object.
      #
      def attr_class(*keys)
        session.attr_class(*keys)
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
      # Used to generate the class string, used in HTML elements (and referenced
      # by CSS rules), for a given attribute's column header cell that takes
      # into account whether the attribute is sortable and, if so, also includes
      # the sorting state currently in effect. The caller provides an attribute
      # instance for which the column header is being rendered.
      #
      # Examples:
      #   form.attr_sort_class(attr_1, "table", "header") => "axis-table-header"
      #   form.attr_sort_class(attr_2, "table", "header") => "axis-table-header-sorting-2-up"
      #   form.attr_sort_class(attr_3, "table", "header") => "axis-table-header-sortable"
      #   form.attr_sort_class(attr_4, "table", "header") => "axis-table-header-sorting-1"
      #
      def attr_sort_class(attr, *prefix)
        if attr.sortable?
          sort = sorts[attr]
          if sort
            # attribute is sortable and we're sorting by it now
            sort.attr_class(*prefix)
          else
            # attribute is sortable; we're just not sorting by it now
            attr_class(*(prefix + ["sortable"]))
          end
        else
          attr_class(*prefix)
        end
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
      def page_total  ; state.page_total  end

      def minimum_in_group     ; SETTINGS[:minimum_in_group     ] end
      def minimum_at_beginning ; SETTINGS[:minimum_at_beginning ] end
      def minimum_at_end       ; SETTINGS[:minimum_at_end       ] end
      def include_first?       ; SETTINGS[:include_first        ] end
      def include_rewind?      ; SETTINGS[:include_rewind       ] end
      def include_prev?        ; SETTINGS[:include_prev         ] end
      def include_next?        ; SETTINGS[:include_next         ] end
      def include_forward?     ; SETTINGS[:include_forward      ] end
      def include_last?        ; SETTINGS[:include_last         ] end
      def always_show_first?   ; SETTINGS[:always_show_first    ] end
      def always_show_rewind?  ; SETTINGS[:always_show_rewind   ] end
      def always_show_prev?    ; SETTINGS[:always_show_prev     ] end
      def always_show_next?    ; SETTINGS[:always_show_next     ] end
      def always_show_forward? ; SETTINGS[:always_show_forward  ] end
      def always_show_last?    ; SETTINGS[:always_show_last     ] end
      def label_first          ; SETTINGS[:label_first   ].html_safe end
      def label_rewind         ; SETTINGS[:label_rewind  ].html_safe end
      def label_prev           ; SETTINGS[:label_prev    ].html_safe end
      def label_next           ; SETTINGS[:label_next    ].html_safe end
      def label_forward        ; SETTINGS[:label_forward ].html_safe end
      def label_last           ; SETTINGS[:label_last    ].html_safe end
      def label_ellipses       ; SETTINGS[:label_ellipses].html_safe end

      def show_first?
        return false unless include_first?
        return true      if always_show_first?
        first_page_range.count <= 0 and main_page_range.min > first_page
      end

      def show_rewind?
        return false unless include_rewind?
        return true      if always_show_rewind?
        show_left_ellipses?
      end

      def show_prev?
        return false unless include_prev?
        return true      if always_show_prev?
        show_left_ellipses? and minimum_in_group <= 1
      end

      def show_next?
        return false unless include_next?
        return true      if always_show_next?
        show_right_ellipses? and minimum_in_group <= 1
      end

      def show_forward?
        return false unless include_forward?
        return true      if always_show_forward?
        show_right_ellipses?
      end

      def show_last?
        return false unless include_last?
        return true      if always_show_last?
        last_page_range.count <= 0 and main_page_range.max < last_page
      end

      def show_left_ellipses?
        first_page_range.count > 0 or main_page_range.min > first_page
      end

      def show_right_ellipses?
        last_page_range.count > 0 or main_page_range.max < last_page
      end

      def first_page ; 1        end
      def prev_page  ; page - 1 end
      def next_page  ; page + 1 end
      def last_page  ; pages    end

      def rewind_page
        [first_page, main_page_range.min].max
      end

      def forward_page
        [last_page, main_page_range.max].min
      end

      def on_first?
        page <= first_page
      end

      def on_last?
        page >= last_page
      end

      #
      # Returns a range object representing the range of pages that are part of
      # the "main" pagination page-number-list group.
      #
      def main_page_range
        lower_bound = [first_page, page - (minimum_in_group / 2)].max
        upper_bound = [last_page, lower_bound + minimum_in_group].min
        # see if we should merge/consume the first_page_range
        lower_bound = first_page if first_page + minimum_at_beginning >= lower_bound
        # see if we should merge/consume the last_page_range
        upper_bound = last_page if last_page - minimum_at_end <= upper_bound
        lower_bound..upper_bound
      end

      #
      # Return a range object representing the range of pages that are part of
      # the "first" pagination page-number-list group (ie, pages 1-x).
      #
      # This will return an "empty" range (result.count == 0) if this page range
      # is subsumed within the main_page_range. Attempting to iterate over this
      # result will produce no result.
      #
      def first_page_range
        upper_bound = first_page + minimum_at_beginning - 1
        main        = main_page_range
        # see if we were merged/consumed by the main_page_range
        upper_bound = first_page - 1 if main.min <= first_page
        first_page..upper_bound
      end

      #
      # Return a range object representing the range of pages that are part of
      # the "last" pagination page-number-list group (ie, pages x-last_page).
      #
      # This will return an "empty" range (result.count == 0) if this page range
      # is subsumed within the main_page_range. Attempting to iterate over this
      # result will produce no result.
      #
      def last_page_range
        lower_bound = last_page - minimum_at_end + 1
        main        = main_page_range
        # see if we were merged/consumed by the main page range
        lower_bound = last_page + 1 if main.max >= last_page
        lower_bound..last_page
      end

      #
      # This returns the absolute total number of records available (the number
      # this form is bound to when no filters are applied).
      #
      def absolute_total
        @absolute_total ||= scoped.count
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
        update_total!
        if state.total > 0
          state.offset ||= 0 # select first if none selected
          @records = paged
          @record  = @records[selected - 1]
        else
          @records = []  # none in current page
          @record  = nil # no record selected
        end
      end

      #
      # This updates the total (as stored in the state) according to how many
      # records match our filters. This new, updated total is then returned.
      #
      def update_total!
        state.total = filtered.count
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
        result = filters.inject(scoped) { |scope, filter| filter.apply(scope) }
        sorts.inject(result)            { |scope, sort  | sort.apply(scope)   }
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
      # Attribute and Attribute::Filter instances).
      #
      # The filters are held in an array-like object, an instance of FilterSet.
      #
      def filters
        @filters ||= FilterSet.new(self)
      end

      #
      # Provide access to the current form's sorts (as Session::Form::Sort
      # instances wrapping State::Sort instances and their associated Attribute
      # and Attribute::Filter instances).
      #
      # The sort instances are held in an array-like object, an instance of
      # SortSet.
      #
      def sorts
        @sorts ||= SortSet.new(self)
      end

      #
      # Update this form's state according to the provided options (from the
      # request's params hash) and the specified command (value of the 'commit'
      # key if present).
      #
      def update(options, command = nil)
        #
        # Set up a catch/throw block so we can short-circuit to the end of the
        # update code path at any point...
        #
        catch(:done) do

          #
          # Process all the shortcut (linkable) axis actions. After this block
          # of code, all future blocks that treat options like a hash will just
          # short-circuit to the end of the method if this block runs (options
          # isn't a hash) successfully (options ends up being a valid offset
          # integer).
          #
          unless options.is_a?(Hash)
            # Support simple "reset" links
            state.reset(true) if options.to_s =~ /^reset$/i
            # See if shorthand offset record selection was used...
            if Normalize.integer(options).is_a?(Integer)
              state.offset = options # fails w/exception if options isn't valid
            end
            throw :done
          end

          #
          # See if there was a request to nuke a filter
          #
          if options[:del]
            if options[:del] == "all"
              filters.reset
            else
              filters.delete_at(options[:del])
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
              state.reset_selection(true) if filters_changed
            elsif command =~ /^reset$/i
              filters.reset unless filters.empty?
            end
          end

          #
          # Process any changes in "per-page" settings
          #
          if options[:per]
            new_per   = Validate.integer(options[:per]) rescue state.per
            state.per = new_per if new_per != state.per
          end

          #
          # Check for sort-clause updates
          #
          if options[:sort] and sortables.keys.include?(options[:sort])
            existing = sorts[sortables[options[:sort]]]
            if existing and existing.priority == 1
              state.reset_selection if existing.reverse
            else
              state.reset_selection if state.sort_by(options[:sort])
            end
          end

          #
          # Check for page and record selection updates
          #
          new_page   = Validate.integer(options[:page],      1) rescue nil
          new_record = Validate.integer(options[:selection], 1) rescue nil
          new_offset = Validate.integer(options[:offset],    0) rescue nil
          new_page   = new_record = nil if new_offset
          if new_page or new_record or new_offset
            update_total!
            if new_offset
              state.offset = new_offset if new_offset < state.total
            else
              state.page     = new_page   if new_page   and state.pages      >= new_page
              state.selected = new_record if new_record and state.page_total >= new_record
            end
          end

        end # catch(:done)
        # If we do nothing else, call reload! in order to select the current
        # set of matching records (if any) and the currently selected record
        # (if there is one).
        reload!
        self
      end

    end
  end
end
