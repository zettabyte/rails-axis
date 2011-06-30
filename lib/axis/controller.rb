# encoding: utf-8
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
    # Get the current "axis session" object (initialized by #axis_before_filter)
    #
    def axis
      @__axis_session__ # yeah, don't directly access this; use the accessor
    end

    ############################################################################
    private
    ############################################################################

    #
    # Initialize the current "axis session" object (an Axis::Session instance)
    # which results in any inbound axis parameters (from a form POST or query
    # string) to be processed, modifying the user's axis state as necessary.
    #
    def axis_before_filter
      Rails.logger.debug "\n\n\n\n#{'*' * 80}\nState Before Request\n#{'*' * 80}"
      Rails.logger.debug "Session:\n\t#{session.inspect}\n"
      Rails.logger.debug "Params:\n\t#{params.inspect}"
      Rails.logger.debug "#{'*' * 80}\n\n\n"
      @__axis_session__ = Axis::Session.new(self)
    end

    #
    # For extending ActionController::Base
    #
    def self.included(base)
      base.before_filter :axis_before_filter
      base.helper_method :axis
      base.helper "axis/url", "axis/gui"
      base.extend ClassMethods
    end

  end
end
