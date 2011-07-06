# encoding: utf-8
module Axis

  #
  # Stores information about the current, persisted state of a "form" (a set of
  # bound UI elements). Each form holds a reference (and, in fact was created
  # based on the presence of) a state instance that was persisted in the
  # underlying session store.
  #
  # The State class is designed to only hold a collection of simple data fields
  # and objects, ultimately composed only of basic ruby nil, boolean, string,
  # numeric, and temporal data types (with a few wrapper sub-classes and an
  # array container or two). Each state persists its relationship with the
  # underlying binding that it's associated with in the "id" field.
  #
  # Ultimately, the state stores record filtering, sorting, pagination and
  # selection information, yielding the concept of a currently selected "page"
  # of records and an individual "selected" record.
  #
  class State

    autoload :Sort,   'axis/state/sort'
    autoload :Filter, 'axis/state/filter'

    # Maximum number of Sort instances (order-clauses) that may be stored per
    # state instance.
    MAX_SORT_CLAUSES = 3

    def initialize(id, per = 25)
      @id  = validate_id(id)
      @per = validate_per(per)
      reset(true)
    end

    attr_reader :id       # our state/binding id number
    attr_reader :per      # number of records per page
    attr_reader :total    # total number of matching records
    attr_reader :page     # which page or records we've got selected (1-based)
    attr_reader :selected # which record on current page we've got selected (1-based)

    def sort    ; @sort    ||= [] end
    def filters ; @filters ||= [] end

    #
    # Total number of pages needed to hold all records.
    #
    def pages
      result = @total / @per
      @total % @per == 0 ? result : result + 1
    end

    #
    # Return the number of records to skip amongst all matching records in order
    # to get to the records of the currently selected page.
    #
    def page_offset
      (@page > 0 ? @page - 1 : 0) * @per
    end

    #
    # Absolute offset of currently "selected" record using a 0-based offset
    # value that takes into account the total number of currently matching
    # records (given the current filters).
    #
    # Returns nil unless there are mathcing records (total has been initialized)
    # and an actual record *is* selected (page and selected fields non-zero).
    #
    def offset
      return nil unless @total > 0 and @page > 0 and @selected > 0
      @per * (@page - 1) + (@selected - 1)
    end

    #
    # Select a record (and page) specifically, using a 0-based offset value
    # that takes into account the total number of currently matching records
    # (given the current filters).
    #
    # Raises an exception if you try to select an offset that's out of range
    # (given the current total) or if, currently, total hasn't been initialized
    # (or the total otherwise *is* zero).
    #
    def offset=(i)
      i = validate_offset(i)
      raise ArgumentError, "cannot select record unless one or more are loaded" unless @total > 0
      raise ArgumentError, "offset index out of range: #{i}"                    unless @total > i
      @page     = i / @per + 1
      @selected = i % @per + 1
    end

    #
    # Set how many records to list per page (preserve record selection)
    #
    def per=(c)
      tmp         = offset # save original offset index
      @per        = validate_per(c)
      @page       = 0
      @selected   = 0
      self.offset = tmp if tmp
    end

    #
    # Initialize or (re)set what the total number of matching records is, taking
    # into account the current set of filters (object's client responsible for
    # performing filtering to derive this value).
    #
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

    #
    # Select which page of records to display (implicitely selects first record
    # of the page) using 1-based page number.
    #
    def page=(p)
      p = validate_page(p)
      raise ArgumentError, "page number out of range: #{p}" unless p <= pages
      @selected = 1 unless @page == p
      @page     = p
    end

    #
    # Select which record on the current page to to be the currently "selected"
    # record (using 1-based record number).
    #
    def selected=(s)
      s   = validate_selected(s)
      max = @page == pages ? @total % @per : @per
      raise ArgumentError, "cannot select record unless a page is selected" unless @page >  0
      raise ArgumentError, "record number out of range: #{s}"               unless max   >= s
      @selected = s
    end

    #
    # Add a sort-clause, it becoming the first-priority sort clause, to the
    # current state object.
    #
    # Returns true if this actually changes the current sort status, otherwise
    # false. Also, note that if true was returned then the currently "selected"
    # record will have been (re)set to the first (offset 0).
    #
    def sort_by(name, descending = false)
      original = @sort.dup
      new_sort = Sort.new(name, descending)
      return false if @sort.first == new_sort
      @sort.reject! { |o| o.name == new_sort.name }
      @sort.unshift(new_sort)
      @sort = @sort[0, MAX_SORT_CLAUSES]
      return false if @sort == original
      self.offset = 0 if @total > 0 # may change @page too
      true # sorting has changed
    end

    #
    # Reset state to original. Returns true if this change in state may trigger
    # a change in the set of "matching" records and/or the "selected" record,
    # otherwise returns false.
    #
    # While doing a reset, you can specify it the record total should be zero-ed
    # out as well, effecting greater change.
    #
    def reset(total = false)
      result = reset_filters(total)
      result = reset_sort    ? true : result
      reset_selection(total) ? true : result
    end

    #
    # Reset (remove) all filters. Returns true if this change in state may
    # trigger a change in the set of "matching" records and/or the "selected"
    # record, otherwise returns false.
    #
    # While doing a reset, you can specify if the record total should be zero-ed
    # out as well, effecting greater change.
    #
    def reset_filters(total = false)
      result   = @filters.any? { |f| f.apply? }
      @filters = []
      result   = reset_selection(true) ? true : result if result or total
      result
    end

    #
    # Reset (remove) all sort clauses. Returns true if this actually triggers
    # a change in state.
    #
    def reset_sort
      result = !@sort.empty?
      @sort  = []
      result = reset_selection ? true : result if result
      result
    end

    #
    # Reset concept of "which" record is selected. If this effects an actual
    # change, then true is returned, otherwise false is returned.
    #
    # While doing a reset, you can specify if the record total should be zero-ed
    # out as well, effecting greater change.
    #
    def reset_selection(total = false)
      result = false
      if @total > 0 # can we change anything anyway?
        if total
          result    = true
          @total    = 0
          @page     = 0
          @selected = 0
        else
          result    = true unless @page == 1 and @selected == 1
          @page     = 1
          @selected = 1
        end
      end
      result
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

  end # class  State
end   # module Axis
