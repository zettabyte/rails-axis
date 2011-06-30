# encoding: utf-8
require 'axis/core_ext/hash'

module Axis
  class Session

    SESSION = "axis".freeze # key for axis entry in main session hash
    PARAMS  = "axis".freeze # key for axis entry in main params  hash

    autoload :Form, 'axis/session/form'

    #
    # Initialize instance and perform our "before filter" logic...
    #
    def initialize(controller)
      @controller = controller
      @action     = controller.action_name
      # NOTE: take care, if ever modifying this method, that you DO NOT place
      #       any calls to #bindings, #states, #forms, or #form (or any method
      #       which calls them) until _after_ the call to #before_filter below!
      #       This is because #before_filter _may_ change the value of @action
      #       and these methods use the #action accessor to lookup bindings and
      #       then cache the results.
      before_filter # update @action and initialize @forms
    end

    #
    # Used to generate the id string, used in HTML elements (and referenced by
    # CSS rules), for a given attribute. The attribute here is defined by a list
    # of values that hierarchically define the attribute. This would be the same
    # set of keys as passed to the #attr_name method, but we're instead
    # generating an HTML id which is used on any/all elements, not just form
    # controls. If no keys are specified, then the main, root HTML id of all
    # axis elements is returned.
    #
    # Examples:
    #   axis.attr_id           => "axis"
    #   axis.attr_id("search") => "axis-search"
    #
    def attr_id(*keys)
      keys.flatten!
      result  = PARAMS.dup
      result += "-#{keys.shift}" until keys.empty?
      result
    end

    #
    # Used to generate the name, used in HTML form controls, for a given axis
    # attribute. The attribute here is defined by a list of values that would be
    # the sequence of keys needed to look up the attribute value in the
    # resulting params hash.
    #
    # Example:
    #   axis.attr_name            => "axis"
    #   axis.attr_name("action",) => "axis[action]"
    #
    def attr_name(*keys)
      keys.flatten!
      result  = PARAMS.dup
      result += "[#{keys.shift}]" until keys.empty?
      result
    end

    #
    # Used to generate a hash which may be provided to URL-constructing helpers
    # in order to create a query-string key and value that, when it is processed
    # in a future request, will yield a params hash entry that needs the same
    # chain (hierarchy) of keys to access to provided value.
    #
    # The last parameter is considered the value and all other parameter are
    # considered part of the key chain.
    #
    # Examples:
    #   axis.attr_hash("action", "reset")
    #     => { "axis" => { "action" => "reset" } }
    #     => "axis[action]=reset" # (after helper converts to query string)
    #   params["axis"]["action"]  # on next request after user clicks link
    #     => "reset"
    #
    #   axis.attr_hash("reset")
    #     => { "axis" => "reset" }
    #     => "axis=reset"
    #   params["axis"]
    #     => "reset"
    #
    # If the last parameter is a hash, then instead of being considered the
    # value it will be considered a "merge" hash and the second-to-the-last
    # parameter will be considered the value. If a "merge" hash is present,
    # then the hash this method normally constructs will be merged with the
    # provided "merge" hash and the result of the merge returned.
    #
    # The merge will favor values in the new hash this method generates over
    # values in the "merge" if there is any conflict.
    #
    # Examples:
    #   axis.attr_hash("action, "reset", "axis" => { "form" => "search" } )
    #     => { "axis" => { "action" => "reset", "form" => "search" } }
    #     => "axis[action]=reset&axis[form]=search"
    #   params["axis"]["action"] => "reset"
    #   params["axis"]["form"]   => "search"
    #
    #   axis.attr_hash("reset", "axis" => { "form" => "search" } )
    #     => { "axis" => "reset" }
    #     ... # (demonstrates merge logic)
    #
    def attr_hash(*keys_and_value)
      key    = PARAMS.dup
      keys   = keys_and_value.flatten
      result = keys.extract_options!.with_indifferent_access
      value  = keys.pop || ""
      handle = result
      until keys.empty?
        handle[key] = {}.with_indifferent_access unless handle[key].is_a?(Hash)
        handle      = handle[key]
        key         = keys.shift
      end
      handle[key] = value
      result
    end

    #
    # Used to generate the id string, used in HTML elements (and referenced by
    # CSS rules), for a given attribute. The attribute here is defined by a
    # list of values that hierarchically define the attribute. This would be
    # the same set of keys as passed to the #attr_name method, but we're
    # instead generating an HTML id which is used on any/all elements, not
    # just form controls. If no keys are specified, then the main, root HTML id
    # of all axis elements is returned.
    #
    # Examples:
    #   form.attr_id           => "axis"
    #   form.attr_id("search") => "axis-search"
    #
    def attr_id(*keys)
      keys.flatten!
      result  = PARAMS.dup
      result += "-#{keys.shift}" until keys.empty?
      result
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
    # Retrieve one of this Axis::Session's forms by either id or handle. If the
    # provided id or handle doesn't match one of the forms, nil is returned. You
    # can pass nil for the handle_or_id and it will try to get the "default"
    # form, this being the one associated with the "default" binding. If you do
    # this but there is no default, nil is returned.
    #
    # See Binding.named for info about default bindings.
    #
    def form(handle_or_id = nil)
      begin # see if we got a binding id...
        id = Validate.integer(handle_or_id, 0)
      rescue ArgumentError ; else
        return forms[id]
      end
      begin # see if we got a binding handle...
        handle = handle_or_id ? Validate.handle(handle_or_id) : nil
      rescue ArgumentError ; return nil
      end
      result = Binding.named(controller, action, handle)
      result ? forms[result.id] : nil
    end

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
      @session ||= @controller.session[SESSION] ||= {}
    end

    #
    # Get a hash of all Axis::Binding instances that are associated with the
    # current controller and action. The instances will be keyed by their id.
    # This makes this essentially a subset of the full binding registry.
    #
    def bindings
      @bindings ||= Hash[
        *Binding.assoc(controller, action).map { |b| [b.id, b] }.flatten
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
        *bindings.keys.map { |id| [id, session[id] ||= State.new(id) ] }.flatten
      ]
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
      options = @controller.params[PARAMS].try(:deep_stringify_keys) || {}

      #
      # See if:
      # 1. This is a POST request and...
      # 2. There's another action mapped to same URL but for GET requests
      # 3. There's a axis[action] parameter with the GET action's name
      #
      # If so, change @action since any/all POST-ed axis parameter date applies
      # to the equivalent GET action instead.
      #
      if @controller.request.post?
        begin
          route   = Rails.application.routes.recognize_path(@controller.request.path, :method => :get)
          @action = route[:action] if route[:action] != @action and options[:action] == route[:action]
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
        @forms[binding.id].update(options[binding.id.to_s], @controller.params[:commit])
      end

      #
      # If we had to change @action to another logical action then assume we
      # were routed to this action in error due to a POST-ed axis form and that
      # the user wishes to remain (or go to) the action they'd have gone to had
      # the request been a GET request: redirect!
      #
      if @controller.request.post? and @action != @controller.action_name
        @controller.redirect_to :action => @action, :status => 303 # "See Other" redirect
      end
    end

  end
end
