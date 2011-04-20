# vim: fileencoding=utf-8:
module Axis

  #
  # Stores information about the current state of an Axis-enabled index page.
  #
  # Since an Axis-enabled index page may display not just a list of records for
  # a given resource, but also sub-resources (etc.) in a hierarchy, a State
  # instance is really a container of State::Entry instances that are organized
  # in a hierarchy and collectively store the page's state. A State instance has
  # one State::Entry that is the "root" entry and stores the state information
  # for the primary resource in question. All other entries are descendants of
  # the root entry.
  #
  class State

    #
    # Stores the actual state data for either the main resource of the page or
    # one of the descendant resources.
    #
    Entry = Struct.new(
      :model,    # String:  name of model class of this entry's resource
      :parent,   # Integer: id of parent entry
      :scope,    # String:  method name; how to get collection of resources
      :total,    # Integer: total no. of resources that match our filters
      :per,      # Integer: max no. of resources to display per page
      :pages,    # Integer: total no. of pages needed to display all resources
      :page,     # Integer: currently selected page of resources
      :selected, # Integer: currently selected resource (on current page)
      :order,    # Array:   list of clauses determining order of resources
      :filters   # Array:   list of filters determining displayed resources
    )

    #
    # Creates a State instance and the "root" entry using the provided data.
    #
    def initialize(model)
      @entries  = [] # the index acts as an entry's "id"; first one must be root
      @entries << Entry.new(model)
      @root     = @entries.first
    end

    attr_reader :root

    private
    def marshal_load(data)
      @entries = data
    end
    def mashal_dump
      @entries
    end

  end
end
