# encoding: utf-8
require 'axis/filter_proxy'

module Axis

  #
  # Stores information about the current state of a set of bound UI elements.
  #
  # Each user session may have one Axis::State instance stored in their session
  # per back-end binding. The binding configures what models are bound to a
  # front-end "form" and a user's state instance stores which records are
  # currently associated (through search filters and column ordering) and which
  # are diplayed (pagination) as well as other user interface configuration
  # settings unique to the client.
  #
  # Thus, each State instance references the Binding it is associated with. You
  # can look up a state instance (or instances) for a controller/action pair
  # by first finding what bindings exist for the pair. Then, using the globally
  # unique binding "id" values as your key(s), you may find any/all associated
  # state instances within the user's session. State instances for a user are
  # all stored in a single hash which itself is stored in the session hash under
  # the configured key ("axis" by default).
  #
  class State
    extend Forwardable # we'll expose many or our binding's methods as our own

    autoload :Order,  'axis/state/order'
    autoload :Filter, 'axis/state/filter'

    MAX_ORDER_CLAUSES = 3

    def initialize(id, per = 25)
      @id  = validate_id(id)
      @per = validate_per(per)
      reset
    end

    # get the actual binding instance associated with this state
    def binding
      Binding[@id]
    end

    #
    # Forward the following method calls to our associated binding...
    #
    def_delegators :binding,
      :controller,
      :action,
      :type,
      :model,
      :handle,
      :scope,
      :parent,
      :children,
      :descendants,
      :root?,
      :child?,
      :parent?,
      :single?,
      :set?

    #
    # Get all the axis attribute instances associated with our model that this
    # instance is bound to. They'll be returned in a hash with the attribute's
    # name being the key.
    #
    # You may pass in an options hash in order to define what kinds of
    # attributes you want. By default all attributes are returned. However, if
    # you pass in an options hash (even an empty one) then only the explicitely
    # requested attributes are returned. The following options define what types
    # of attributes you can request:
    #
    #   :display => true # return displayable attribute
    #   :search  => true # return attributes that are searchable
    #   :sort    => true # return sortable attributes
    #
    def attributes(options = nil)
      result  = Attribute[model]
      options = options.intern      if options.is_a?(String) && %w{ display search sort }.include?(options)
      options = { options => true } if options.is_a?(Symbol)
      if options.is_a?(Hash)
        result.reject! do |k, v|
          (options[:diplay] and !v.displayable?) or
          (options[:search] and !v.searchable? ) or
          (options[:sort]   and !v.sortable?   )
        end
      end
      result
    end

    attr_reader :id       # our state/binding id number
    attr_reader :per      # number of records per page
    attr_reader :total    # total number of matching records
    attr_reader :page     # which page or records we've got selected (1-based)
    attr_reader :selected # which record on current page we've got selected (1-based)

    # access copy of our array: list of Order objects determining order of resources
    def order
      @order.dup
    end

    # access copy of our array: list of Filter objects determining displayed
    # resources (wrapped in proxy container that joins it w/the attribute's
    # filter instance)
    def filters
      attrs = attributes(:search)
      @filters.map { |f| FilterProxy.new(attrs[f.name].filter, f) }
    end

    # helper for getting number of filters w/o running proxy-ing code in #filters
    def num_filters
      @filters.length
    end

    # total number of pages to hold all records
    def pages
      result = @total / @per
      @total % @per == 0 ? result : result + 1
    end

    # absolute offset of current record (0-based) amongst all matching records
    def offset
      # unless we've got records and one of them selected, return nil
      return nil unless @total > 0 and @page > 0 and @selected > 0
      @per * (@page - 1) + (@selected - 1)
    end

    # select a record from all records using 0-based offset (or pass false/nil to de-select any records)
    def offset=(i)
      i = validate_offset(i)
      raise ArgumentError, "cannot select record unless one or more are loaded" unless @total > 0
      raise ArgumentError, "offset index out of range: #{i}"                   unless @total > i
      @page     = i / @per + 1
      @selected = i % @per + 1
    end

    # set how many records to list per page (preserve record selection)
    def per=(c)
      tmp         = offset # save original offset index
      @per        = validate_per(c)
      @page       = 0
      @selected   = 0
      self.offset = tmp if tmp
    end

    # allow user to manually override (set) what the total record count is...
    def total=(t)
      @total = validate_total(t)
      if @total < 1
        @page     = 0
        @selected = 0
      elsif @total <= offset
        self.offset = @total - 1 # select last record
      end
    end

    # select which page of records to display (implicitely selects first record of page)
    def page=(p)
      p = validate_page(p)
      raise ArgumentError, "page number out of range: #{p}" unless p <= pages
      @selected = 1 unless @page == p
      @page     = p
    end

    # select which record on the current page to display
    def selected=(s)
      s   = validate_selected(s)
      max = @page == pages ? @total % @per : @per
      raise ArgumentError, "cannot select record unless a page is selected" unless @page >  0
      raise ArgumentError, "record number out of range: #{s}"               unless max   >= s
      @selected = s
    end

    # order records by the specified attribute
    def order_by(name, descending = false)
      new_order = Order.new(name, descending)
      return self if @order.first == new_order
      @order.reject! { |o| o.name == new_order.name }
      @order.unshift(new_order)
      @order      = @order[0, MAX_ORDER_CLAUSES]
      self.offset = 0 if @total > 0
      self # this method is chainable
    end

    # reset the "selection" state
    def reset_selection
      @total    = 0
      @page     = 0
      @selected = 0
      self # this method is chainable
    end

    # reset the order to the default (no order clauses)
    def reset_order
      @order = []
      if @total > 0
        @page     = 1
        @selected = 1
      end
      self # this method is chainable
    end

    # reset filter list to original (no records filtered yet)
    def reset_filters
      @filters  = []
      reset_selection
      self # this method is chainable
    end

    # reset state to original (no records yet loaded)
    def reset
      reset_filters # also calls reset_selection
      reset_order
      self # this method is chainable
    end

    #
    # Process axis update requests for this state instance...
    #
    def update(options, command = nil)
      return self  unless options # nil is legal, we just don't do anything
      return reset if     options == "reset"

      #
      # See if shorthand offset record selection was used...
      #
      #i = normalize_offset(options)
      #if i.is_a?(Integer)
      #  self.offset = i rescue nil
      #end
      #return self unless options.is_a?(Hash)

      #
      # See if there was a request to nuke a filter
      #
      if options[:del]
        i = Validate.integer(options[:del], 0) rescue nil
        if options[:del] == "all"
          reset_filters
        elsif i and i < @filters.length
          @filters.delete_at(i)
          reset_selection
        end
      end

      #
      # See if there was a request to add a filter
      #
      if options[:add]
        attribute = attributes(:search).values.find { |a| a.name == options[:add] }
        @filters << Filter.new(attribute.name) if attribute
        reset_selection
      end

      #
      # Check for filter updates
      #
      #if options[:filter]
      #  if options[:filter] == "reset"
      #    reset_filters
      #  elsif options[:filter].is_a?(Hash)
      #    new_filter = options[:filter].delete(:new)
      #    filter_map = @filters.
      #  end
      #end

      # 1. check for filter updates
      #   b. specific filter commands:
      #     i)   delete filter: axis[0][filter][0]=delete
      #     ii)  update filter: axis[0][filter][0]={}
      # 2. check for order-clause updates
      #   a. modify active order commands: axis[0][order]=reset, =desc, =asc, =rev
      #   b. specific order commands: ={:by => attr_name [, :dir => one of: :asc, :desc]}
      # 3. check for page selection/navigation
      #   a. page selection: axis[0][page]=5 / axis[0][page]=first, =last, :next, :prev, :none, :reset
      # 4. check for record selection
      #   a. record selection: axis[0][select]=2 / axis[0][select]=first, =last, :next, :prev, :none, :reset
      #   b. offset selection: axis[0][offset]=0
      self
    end

    ############################################################################
    private
    ############################################################################

    def validate_id(v)
      result = Validate.integer(v, 0)
      raise ArgumentError, "invalid binding id: #{v}" unless Binding[result].is_a?(Binding)
      result
    end
    def validate_per(v)      ; Validate.integer(v, 1..1000) end
    def validate_total(v)    ; Validate.integer(v, 0)       end
    def validate_offset(v)   ; Validate.integer(v, 0)       end
    def normalize_offset(v)  ; Normalize.integer(v)         end
    def validate_page(v)     ; Validate.integer(v, 1)       end
    def validate_selected(v) ; Validate.integer(v, 1)       end

  end # class State
end   # module Axis
