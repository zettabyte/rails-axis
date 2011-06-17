# encoding: utf-8
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

    ############################################################################
    private
    ############################################################################

    def axis_before_filter
      #
      # Initialize a state instance for each binding on the form
      #
      @axis        = {}.with_indifferent_access # main axis interface hash
      axis_session = session["axis"] ||= {}
      bindings     = Binding.assoc(self.class, action_name)
      bindings.each do |b|
        axis_session[b.id] = State.new(b.id) unless axis_session[b.id]
        @axis[b.handle] = @axis[b.id] = axis_session[b.id]
      end

      #
      # Don't do anything more unless this is a request with axis updates
      #
      options = params.delete("axis")
      return unless options.is_a?(Hash)

      #
      # Process any binding update data in binding-hierarchical order
      #
      queue = Binding.root(self.class, action_name)
      until queue.empty?
        binding = queue.shift      # get next binding to be processed...
        queue  += binding.children # add direct children to end of queue...
        @axis[b.id].update(options[binding.id]) # update the state
      end
    end

    def self.included(base)
      base.before_filter :axis_before_filter
      base.helper Axis::UrlHelper, Axis::GuiHelper
      base.extend ClassMethods
    end

  end
end
