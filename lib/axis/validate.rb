# encoding: utf-8
require 'axis/normalize'

module Axis
  module Validate

    #
    # Normalize and validate any acceptable forms for "controller" parameters.
    # If the parameter is not in a valid form that represents a controller class
    # then an ArgumentError is raised. Otherwise, the normalized form of the
    # parameter is returned (a Class instance for a class that has
    # ActionController::Base as an ancestor).
    #
    def controller(arg)
      result = Normalize.controller(arg)
      raise ArgumentError, "invalid type for controller: #{arg.class}" unless result.is_a?(Class)
      raise ArgumentError, "invalid controller: #{arg.name}"           unless result.ancestors.include?(ActionController::Base)
      result
    end
    module_function :controller

    #
    # Normalize and validate any acceptable forms for "action" parameters. If
    # the parameter is not in a valid form that represents an action (public,
    # instance method name) on an ActionController class then an ArgumentError
    # is raised. Otherwise, the normalized form of the parameter is returned (a
    # string).
    #
    # There are two possible validations: partial and complete.
    #
    # ====== Partial Validation ======
    #
    # To do parital validation, just provide a single parameter (the action
    # name). In this instance, only the type of the parameter (and some other
    # simple constraints) are checked. It is not verified that any such method
    # exists within any ActionController class (it can't since it has no such
    # controller to check against).
    #
    # ====== Complete Validation ======
    #
    # To do complete validation, you must additionally provide a valid
    # controller in addition to your action. The controller will be validated as
    # a side-effect, but be aware that this will occur if you provide a
    # controller. The controller is validated using #controller above.
    #
    # Then, once a validated ActionController class is available and after the
    # action has been normalized, the controller is used to ensure that the
    # named action exists as a public instance method on the provided controller
    # class. If not, an exception is raised.
    #
    def action(arg, controller_arg = nil)
      controller_arg = controller(controller_arg) if controller_arg
      result         = Normalize.action(arg)
      raise ArgumentError, "invalid type for action: #{arg.class} (#{arg})" unless result.is_a?(String)
      raise ArgumentError, "invalid action: #{result}" unless result =~ /\A[a-z_]\w*\z/i
      raise ArgumentError, "invalid action: #{result} (not an action method in controller: #{controller_arg.name})" if
        controller_arg and !controller_arg.action_methods.include?(result)
      result
    end
    module_function :action

    #
    # Normalize and validate any acceptable forms for "model" parameters. If the
    # parameter is not in a valid form that represents a model class then an
    # ArgumentError is raised. Otherwise, the normalized form of the parameter
    # is returned (a Class instance for a class that has ActiveRecord::Base as
    # an ancestor).
    #
    def model(arg)
      result = Normalize.model(arg)
      result = result.to_s                 if result.is_a?(Symbol) # special-
      result = result.camelize.constantize if result.is_a?(String) # case
      raise ArgumentError, "invalid type for model: #{arg.class} (#{arg})" unless result.is_a?(Class)
      raise ArgumentError, "invalid model: #{result.name}" unless result.ancestors.include?(ActiveRecord::Base)
      result
    end
    module_function :model

    #
    # Normalize and validate any acceptable forms for "column" parameters. If
    # the parameter is not in a valid form that represents a column (attribute)
    # name on an ActiveRecord model class then an ArgumentError is raised.
    # Otherwise, the normalized form of the parameter is returned (a string).
    #
    # There are two possible validations: parital and complete.
    #
    # ====== Partial Validation ======
    #
    # To do partial validation, just provide a single parameter (a column name).
    # In this instance, only the type of the parameter (and some other simple
    # contraints) are checked. It is not verified that any such column exists
    # within any ActiveRecord model (it can't since it has no model to check
    # against).
    #
    # ====== Complete Validation ======
    #
    # To do complete validation, you must additionally provide a valid model
    # in addition to your column. The model will be validated as a side-effect,
    # but be aware that this will occur if you provide a model. The model is
    # validated using #model above.
    #
    # Then, once a validated ActiveRecord model class is available and after the
    # column has been normalized, the model is used to ensure that the named
    # column exists in the table associated with the provided model. If not, an
    # exception is raised.
    #
    def column(arg, model_arg = nil)
      model_arg = model(model_arg) if model_arg
      result    = Normalize.column(arg)
      raise ArgumentError, "invalid type for column: #{arg.class} (#{arg})" unless result.is_a?(String)
      raise ArgumentError, "invalid column: #{result}" if result.blank?
      raise ArgumentError, "invalid column: #{result} (not in table: #{model_arg.table_name})" if
        model_arg and !model_arg.column_names.include?(result)
      result
    end
    module_function :column

    #
    # Normalize and validate any acceptable forms for list of "columns"
    # parameters. If the parameter is not in a valid form that represents a list
    # of one or more column (attribute) names on an ActiveRecord model class
    # then an ArgumentError is raised. Otherwise, the normalized form of the
    # parameter is returned (an array of strings).
    #
    # There are two possible validations: parital and complete. The differences
    # between them are identical and documented in the #column (singular) method
    # above.
    #
    def columns(arg, model_arg = nil)
      model_arg = model(model_arg) if model_arg
      result    = Normalize.columns(arg)
      raise ArgumentError, "invalid type for column list: #{arg.class} (#{arg})" unless result.is_a?(Array)
      result.each do |c|
        column(c) # avoid re-validating model_arg for each element
        raise ArgumentError, "invalid column: #{c} (not in table: #{model_arg.table_name})" if
          model_arg and !model_arg.column_names.include?(c)
      end
      raise ArgumentError, "no columns provided" if result.empty?
      result
    end
    module_function :columns

    #
    # Normalize and validate any acceptable forms for integer parameters. If the
    # parameter is no in a valid form that is either numeric (and an integer or
    # whole part can be extracted) or a string or symbol (consisting only of
    # digits with an optional leading sign) then an ArgumentError is raised.
    # Otherwise, the normalized form of the parameter is returned (an Integer).
    #
    # You may also optionally pass a range (of integers) as a second parameter.
    # If you do, the parameter will also be validated that it belongs within the
    # provided range.
    #
    # Another option is to instead pass a single integer for the optional second
    # parameter. If this is done, then the parameter will be validated as being
    # greater-than or equal-to this value.
    #
    # There is no variation for checking *only* against a maximum value. For a
    # maximum, you must use a range (which will also enforce a minimum).
    #
    def integer(arg, range_or_minimum = nil)
      result = Normalize.integer(arg)
      raise ArgumentError, "invalid type for an integer: #{arg.class} (#{arg})" unless result.is_a?(Integer)
      if range_or_minimum.is_a?(Range)
        raise ArgumentError, "invalid integer (out of range: #{range_or_minimum}): #{result}" unless range_or_minium.include?(result)
      else
        raise ArgumentError, "invalid integer (below minimum: #{range_or_minimum}): #{result}" unless result >= range_or_minimum
      end
      result
    end
    module_function :integer

  end
end
