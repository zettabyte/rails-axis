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

      #
      # The following just provide proxied-access to the associated members on
      # the form's binding.
      #
      def id     ; @id     ||= binding.id     end
      def model  ; @model  ||= binding.model  end
      def scope  ; @scope  ||= binding.scope  end
      def type   ; @type   ||= binding.type   end
      def handle ; @handle ||= binding.handle end

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
      def per      ; state.per      end
      def page     ; state.page     end
      def selected ; state.selected end
      def total    ; state.total    end

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
        #
        # Don't do anything unless options is somethine (it's legal to pass nil
        # in though we don't do anything)
        #
        return self unless options

        #
        # Support simple "reset" links
        #
        if options =~ /^reset$/i
          state.reset
          return self
        end

        #
        # See if shorthand offset record selection was used...
        #
        i = Normalize.integer(options)
        if i.is_a?(Integer)
          state.offset = i rescue nil
        end

        #
        # At this point, all other actions will be represented by options being
        # a hash. So, if it isn't a hash, we're done...
        #
        return self unless options.is_a?(Hash)

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
          if command =~ /^update$/
            filters_changed = false
            changes         = options[:filter] || {}
            filters.each_with_index do |filter, filter_id|
              filters_changed ||= filter.update(changes[filter_id.to_s])
            end
            state.reset_selection if filters_changed
          elsif command =~ /^reset$/i
            filters.reset unless filters.empty? or !filters.any? { |f| f.apply? }
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

        self
      end

    end
  end
end
