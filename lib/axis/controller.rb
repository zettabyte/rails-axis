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

    ############################################################################
    private
    ############################################################################

    def axis_before_filter
      # Don't do anything unless this is a GET request with axis data
      return unless method == :get and params["_axis"]
      controller = self.class
      action     = action_name
      options    = params.delete("_axis")

      # See if any filter modifications made...
      if options.is_a?(String) and options =~ /\A\d+\z/
        binding = Binding[options.to_i]
        raise "invalid binding id (controller doesn't match): #{options}" unless binding.controller == controller
        raise "invalid binding id (action doesn't match): #{options}"     unless binding.action     == action
        # check for a reset, then for a filter-delete, then for a filter-add, then for a filter-update
        case params["commit"]
        when "Reset"
          # TODO: nuke all existing filters
        when "Delete"
          # TODO: delete specified filter
        when "Add"
          # TODO: add a new filter (check for per-page change(s))
        when "Update"
          # TODO: update all filters' values (including per-page change(s))
        else
          raise "invalid axis request: #{params["commit"]}" if params["commit"]
        end
        # TODO: recompute list of SQL filters, detecting any logical change(s)
        # TODO: if any filter changes made, reset page, selected, total, pages, etc...
        # TODO: if any changes made to page and/or selected, reset child binding's page/selected recursively...
      end

      Binding.assoc(controller, action).each do |binding|
        state = axis_binding_state(binding.id)
        if params["_axis"] and params["_axis"][binding.id]
          options = params["_axis"].delete(binding.id)
          #
          # per-page change  --> update pages (reset page/selected if changed)
          # order change(s)  --> reset page/selected if changed
          # page selection   --> update selected if changed
          # selection change --> done!
          #
        end
      end
    end

    def axis_session
      session["axis"] ||= {}
    end

    def axis_binding_state(binding_id)
      raise ArgumentError, "invalid type for binding_id: #{binding_id.class} (#{binding_id})" unless binding_id.is_a?(Fixnum)
      raise ArgumentError, "invalid value for binding_id: #{binding_id}" unless (0...Binding.count).member?(binding_id)
      raise ArgumentError, "invalid binding_id (binding refers to different controller): #{binding_id}" unless Binding[binding_id].controller == self.class
      raise ArgumentError, "invalid binding_id (binding refers to different action): #{binding_id}" unless Binding[binding_id].action == action_name
      axis_session[binding_id] ||= State.new(binding_id, 0, 25, 0, 1, nil, [], [])
    end

    def self.included(base)
      base.before_filter :axis_before_filter
      base.helper_method :axis_state
      base.extend ClassMethods
    end

  end
end
