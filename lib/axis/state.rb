# vim: fileencoding=utf-8:
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
  State = Struct.new(
    :id,       # Integer: "id" of associated Binding instance
    :total,    # Integer: total no. of resources that match our filters
    :per,      # Integer: max no. of resources to display per page
    :pages,    # Integer: total no. of pages needed to display all resources
    :page,     # Integer: currently selected page of resources
    :selected, # Integer: currently selected resource (on current page)
    :order,    # Array:   list of clauses determining order of resources
    :filters   # Array:   list of filters determining displayed resources
  )

  class State
    #
    # Defines what should be stored as an entry within the #order array.
    #
    Order = Struct.new(
      :column,   # name of column to order by
      :ascending # true if an ASC[ENDING] order clause, false for DESC[ENDING]
    )
    #
    # Defines what should be stored as an entry within the #filters array.
    #
    Filter = Struct.new(
      :column, # name of column/field we're filtering on
      :val1,   # filter value (first in case of multi-valued filters)
      :val2    # filter value (optional second one for multi-values filters)
    )
  end # class State
end   # module Axis
