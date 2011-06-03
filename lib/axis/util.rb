# vim: fileencoding=utf-8:
require 'axis/validate'

module Axis
  module Util

    #
    # Tries to "guess" a model given a controller. You provide a controller (as
    # a symbol, string, or actual Class instance) and the controller's name is
    # used to try to come up with a model class.
    #
    # If successful, the model Class instance is returned. Otherwise an
    # exception is raised.
    #
    def model_from_controller(controller)
      controller = Validate.controller(controller)
      name       = controller.name.demodulize
      prefix     = controller.name.sub(Regexp.new(Regexp.escape(name) + "$"), "")
      name       = prefix + name.underscore.sub(/_controller$/, "").singularize.classify
      Validate.model(name)
    end
    module_function :model_from_controller

  end
end
