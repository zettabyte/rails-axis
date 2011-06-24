# encoding: utf-8
require 'axis/core_ext/hash'

module Axis
  class Session

    autoload :Form, 'axis/session/form'

    #
    # Initialize instance and perform our "before filter" logic...
    #
    def initialize(controller)
      @controller = controller
      @action     = controller.action_name
      # NOTE: take care, if ever modifying this method, that you DO NOT place
      #       any calls to #bindings, #states, or #state (or any method which
      #       calls them) until _after_ the call to #before_filter below! This
      #       is because #before_filter _may_ change the value of @action and
      #       these methods use the #action accessor to lookup bindings (and
      #       they cache the results).
      before_filter # update @action and initialize @forms
    end

    #
    # Returns the logical axis action name. This may not be the action name of
    # the current request (in some circumstances). For more info, see the
    # #before_filter implementation (which may change @action) for details.
    #
    attr_reader :action

    #
    # Returns the collection of Axis::Session::Form instances associated with
    # the current controller and logical axis action.
    #
    attr_reader :forms

    #
    # Return the current controller's class (not the instance)
    #
    def controller
      @controller.class
    end

    #
    # Get a reference to the session-stored hash of Axis::State instances that
    # are, so far, associated with the current controller and action.
    #
    def session
      @session ||= @controller.session["axis"] ||= {}
    end

    #
    # Get a hash of all Axis::Binding instances that are associated with the
    # current controller and action. The instances will be keyed by their id.
    # This makes this essentially a subset of the full binding registry.
    #
    def bindings
      @bindings ||= Hash[
        Binding.assoc(controller, action).map { |b| [b.id, b] }.flatten
      ]
    end

    #
    # Get a hash of all Axis::State instances that are associated with all the
    # bindings associated with the current controller and action. The instances
    # will be keyed by their id (also the binding id). This makes this
    # essentially a subset of the full registry of all states persisted in the
    # user's session.
    #
    # NOTE: This has the side-effect of initializing and persisting (in the
    #       session) a new Axis::State instance for each binding associated with
    #       the current controller/action for which a state instance doesn't
    #       already exist. The #before_filter takes advantage of this side-
    #       effect.
    #
    #       Also, mutating the returned hash WILL NOT mutate or effect the hash
    #       collection that is stored in the user's session. However, mutating
    #       individual Axis::State instances DOES mutate the state instances
    #       stored in the user's session.
    #
    def states
      @states ||= Hash[
        bindings.keys.map { |id| [id, session[id] ||= State.new(id) ] }.flatten
      ]
    end

    #
    # Get an individual Axis::State instance by either specifying its (binding)
    # id or its (binding) handle. If you don't provide anything, it assumes you
    # want the state for the "default" binding (if there is a default). If the
    # parameter is a valid integer or handle value, but doesn't refer to a
    # binding for this controller and action, then nil is returned. Also, if you
    # don't provide anything (requesting the "default" binding's state) then nil
    # is returned if there is no default binding.
    #
    # See Binding.named for info about default bindings.
    #
    def state(handle_or_id = nil)
      begin # see if we got a binding id...
        id = Validate.integer(handle_or_id, 0)
      rescue ArgumentError ; else
        return states[id] # returns nil if id isn't associated controller/action
      end
      begin # see if we got a binding handle...
        handle = handle_or_id ? Validate.handle(handle_or_id) : nil
      rescue ArgumentError ; return nil
      end
      binding = Binding.named(controller, action, handle)
      binding ? states[binding.id] : nil
    end

    private

    #
    # Used to process any axis-specific data in the params hash in order to
    # mutate the user's axis state...
    #
    # Responsible for updating @action if, due to routing, POST-ed axis data
    # actually applies to another (GET) action w/the same URL.
    #
    def before_filter
      #
      # Don't do anything unless this is a request with axis updates
      #
      options = @controller.params[:axis].try(:deep_stringify_keys)
      return unless options.is_a?(Hash)

      #
      # See if:
      # 1. This is a POST request and...
      # 2. There's another action mapped to same URL but for GET requests
      #
      # If so, change @action since any/all POST-ed axis parameter date applies
      # to the equivalent GET action instead.
      #
      if @controller.request.post?
        begin
          route   = Rails.application.routes.recognize_path(@controller.request.path, :method => :get)
          @action = route[:action] if route[:action] != @action
        rescue ActionController::RoutingError
        end
      end

      #
      # NOTE: Okay! @action is *set* at this point! We should now use the
      #       #action accessor from here on out. Also, it is now safe to call
      #       #bindings (and, by extension, #states, and #state) as the correct
      #       set of bindings will be cached.
      #
      # Initialize our collection for Axis::Session::Form instances to wrap
      # individual binding/state pairs. Then, update them with any available
      # axis data. Process the forms according to the nested binding hierarhcy
      # (so that sub-forms' concept of their record(set) will reflect changes
      # to their parents' newly selected records).
      #
      @forms = {} # keyed by binding id
      queue  = Binding.root(controller, action)
      until queue.empty?
        binding = queue.shift      # get next binding to be processed...
        queue  += binding.children # add direct children to end of queue...
        @forms[binding.id] = Form.new(self, binding, states[binding.id])
        @forms[binding.id].update(options[binding.id.to_s], params[:commit])
      end

      #
      # If we had to change @action to another logical action then assume we
      # were routed to this action in error due to a POST-ed axis form and that
      # the user wishes to remain (or go to) the action they'd have gone to had
      # the request been a GET request: redirect!
      #
      if @controller.request.post? and @action != @controller.action_name
        @controller.redirect_to :action => @action
      end
    end

  end
end
