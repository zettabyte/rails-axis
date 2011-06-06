# vim: fileencoding=utf-8:
module Axis
  module Controller
    module ClassMethods

      #
      # For each named controller action, create a binding (or full hierarchy of
      # bindings) using the provided options.
      #
      def axis_on(*args)
        options = args.extract_options!
        args    = args.flatten.uniq
        args   << :index if args.empty?
        args.each do |action|
          Binding.bind(self, action, options)
        end
      end

    end

    #
    # Grab a state (or collection of state) instance(s) associated with the
    # current controller/action pair, optionally selecting a specific one from
    # the heirarchy using the provided parameter(s) as selectors.
    #
    # NOTE: This method is _noisy_! It raises ArgumentError if you pass
    #       parameter(s) that DO NOT correspond/select an actual binding!
    #
    # Returns nil of the selected binding has no state instance associated with
    # it yet. Otherwise it either returns a state instance, or a Hash (a
    # collection, possibly hierarchy) of state instances nested at and/or below
    # the current selection point.
    #
    def axis_state(*args)
    end

    ############################################################################
    private
    ############################################################################

    def axis_before_filter
      # determine controller and action pairing, load all any/all bindings for pair
      # grab any state objects from session that relate to any of these bindings (or their descendants)
      # initialize any new state instances for any/all bindings that don't already have one and store ref. in session
      # parse out each group of passed parameters dealing with any binding: .each do |params|
      #   update associated state based on passed params
      # end
    end

    def self.included(base)
      base.before_filter :axis_before_filter
      base.helper_method :axis_state
      base.extend ClassMethods
    end

  end
end
