# encoding: utf-8
module Axis

  #
  # Stores information about the current state of a set of bound UI elements.
  #
  # Each user session may have one Axis::State instance stored in their session
  # per back-end binding. The binding configures what models are bound to a
  # front-end "form" and a user's state instance stores which records are
  # currently associated (through search filters and column sorting) and which
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

    autoload :Sort,   'axis/state/sort'
    autoload :Filter, 'axis/state/filter'

    MAX_SORT_CLAUSES = 3

    def initialize(id, per = 25)
      @id  = validate_id(id)
      @per = validate_per(per)
      reset
    end

    attr_reader :id       # our state/binding id number
    attr_reader :per      # number of records per page
    attr_reader :total    # total number of matching records
    attr_reader :page     # which page or records we've got selected (1-based)
    attr_reader :selected # which record on current page we've got selected (1-based)

    def sort    ; @sort    ||= [] end
    def filters ; @filters ||= [] end

    # total number of pages to hold all records
    def pages
      result = @total / @per
      @total % @per == 0 ? result : result + 1
    end

    # number of records to skip in amongst all matching records in order to get
    # to the records of the current page
    def page_offset
      (@page > 0 ? @page - 1 : 0) * @per
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
      raise ArgumentError, "offset index out of range: #{i}"                    unless @total > i
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
        return
      end
      offset ||= 0 # select first record if none selected
      if @total <= offset
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

    # sort records by the specified attribute
    def sort_by(name, descending = false)
      new_sort = Sort.new(name, descending)
      return self if @sort.first == new_sort
      @sort.reject! { |o| o.name == new_sort.name }
      @sort.unshift(new_sort)
      @sort      = @sort[0, MAX_SORT_CLAUSES]
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

    # reset the sorting to the default (no sort clauses)
    def reset_sort
      @sort = []
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
      reset_sort
      self # this method is chainable
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
