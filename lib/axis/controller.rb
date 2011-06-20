# encoding: utf-8
require 'axis/core_ext/hash'

module Axis
  module Controller

    ############################################################################
    module ClassMethods
    ############################################################################

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

    ############################################################################
    end
    ############################################################################

    #
    # Standard interface to get the hash of all the state instances, keyed by
    # their associated binding ids (integers). Most user code, however, won't
    # need direct access to this and should instead use #axis_state below to
    # get the individual state instances they need to work on.
    #
    def axis_session
      session["axis"] ||= {}
    end

    #
    # Since most rendering operations are based on an axis state instance stored
    # in the user's session which, in turn, is associated to a binding (which
    # links to a model), this allows you to quickly get a handle to the state
    # instance.
    #
    # You can either provide a handle, and id, or nothing. The handle or id must
    # refer to an binding's handle or id, otherwise nil is returned. If the
    # handle or id *does* refer to a binding on the current controller/action
    # pair then the state (possibly a newly initialized one) instance associated
    # with it for the current user's session is returned.
    #
    # If you don't provide a handle or id, then there must be a "default"
    # binding. If not, nil is returned. See Binding.named for info about default
    # bindings. If there is a default then its associated state instance is
    # returned.
    #
    def axis_state(handle_or_id = nil)
      # See if we got a binding id...
      begin
        id = Validate.integer(handle_or_id, 0)
      rescue ArgumentError
      else
        return Binding[id] ? axis_session[id] ||= State.new(id) : nil
      end
      # Now we can assume they've tried to pass a binding's handle or want the
      # default binding...
      begin
        handle = handle_or_id ? Validate.handle(handle_or_id) : nil
      rescue ArgumentError
        return nil
      end
      binding = Binding.named(self.class, action_name, handle)
      binding ? axis_session[binding.id] ||= State.new(binding.id) : nil
    end

    ############################################################################
    private
    ############################################################################

    def axis_before_filter
      routes = Rails.application.routes # so we can query the router

      #
      # Don't do anything unless this is a request with axis updates
      #
      options = params.delete(:axis).try(:deep_stringify_keys)
      return unless options.is_a?(Hash)

      #
      # See if (A):
      # 1. This is a POST request
      # 2. There's another action mapped to same URL but for GET requests
      # 3. The axis data applies to this other action
      #
      # Then (B):
      # 1. Apply axis data to this *other* action
      # 2. If there's no other POST data, redirect to this other action
      #
      # Otherwise (C):
      #    Just apply axis data to this action's bindings' state
      #
      axis_action = action_name
      if request.post?
        begin
          alt_route   = routes.recognize_path(request.path, :method => :get)
          axis_action = alt_route[:action] if alt_route[:action] != action_name
        rescue ActionController::RoutingError
        end
      end

      #
      # (C & B.1) Process any binding update data in binding-hierarchical order
      #
      queue = Binding.root(self.class, axis_action)
      until queue.empty?
        binding = queue.shift      # get next binding to be processed...
        queue  += binding.children # add direct children to end of queue...
        axis_state(binding.id).update(options[binding.id.to_s], params[:commit])
      end

      #
      # (B.2) "If there's no other POST data..."
      #
      if request.post? and axis_action != action_name
        Rails.logger.debug "\n\n\nOooh, looks like a redirect (#{params.inspect})...\n\n\n"
        redirect_to :action => axis_action if params.reject do |k, v|
          %w{ controller action id commit authenticity_token utf8 }.include?(k.to_s)
        end.empty?
      end

    end

    def self.included(base)
      base.before_filter :axis_before_filter
      base.helper "axis/url", "axis/gui"
      base.extend ClassMethods
    end

  end
end
