# vim: fileencoding=utf-8:
require 'axis/railtie' if defined?(Rails)

#
# This is the base module for the Axis rails gem. This module includes several
# general-purpose utility methods (such as normalization and validation methods)
# and constants. It otherwise serves to namespace the Axis classes.
#
module Axis

  autoload :Attribute,  'axis/attribute'
  autoload :Binding,    'axis/binding'
  autoload :Controller, 'axis/controller'
  autoload :Model,      'axis/model'
  autoload :State,      'axis/state'
  autoload :Version,    'axis/version'

  ##############################################################################
  class << self
  ##############################################################################

    #
    # Convert any acceptable forms for "controller" parameters into a standard
    # form, namely a Class instance. Returns the parameter as-is if it is
    # already in standard form or if it is in an invalid form. This doesn't
    # raise errors.
    #
    def normalize_controller(controller)
      controller = controller.to_s if controller.is_a?(Symbol)
      controller = controller.camelize.constantize rescue controller if controller.is_a?(String)
      controller
    end

    #
    # Normalize and validate any acceptable forms for "controller" parameters.
    # If the parameter is not in a valid form that represents a controller class
    # then an ArgumentError is raised. Otherwise, the normalized form of the
    # parameter is returned (a Class instance for a class that has
    # ActionController::Base as an ancestor).
    #
    def validate_controller(controller)
      result = normalize_controller(controller)
      raise ArgumentError, "invalid type for controller: #{controller.class}" unless result.is_a?(Class)
      raise ArgumentError, "invalid controller: #{controller.name}"           unless result.ancestors.include?(ActionController::Base)
      result
    end

    #
    # Convert any acceptable forms for "action" parameters into a standard form,
    # namely a string. Returns the parameter as-is if it is already a string or
    # if it is in an invalid form. This doesn't raise errors.
    #
    def normalize_action(action)
      action.is_a?(Symbol) ? action.to_s : action
    end

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
    # controller. The controller is validated using #validate_controller above.
    #
    # Then, once a validated ActionController class is available and after the
    # action has been normalized, the controller is used to ensure that the
    # named action exists as a public instance method on the provided controller
    # class. If not, an exception is raised.
    #
    def validate_action(action, controller = nil)
      controller = validate_controller(controller) if controller
      result     = normalize_action(action)
      raise ArgumentError, "invalid type for action: #{action.class} (#{action})" unless result.is_a?(String)
      raise ArgumentError, "invalid action: #{result}" unless result =~ /\A[a-z_]\w*\z/i
      raise ArgumentError, "invalid action: #{result} (not an action method in controller: #{controller.name})" if
        controller and !controller.action_methods.include?(result)
      result
    end

    #
    # Convert any acceptable forms for "model" parameters into a standard form,
    # namely a Class instance. Returns the parameter as-is if it is already in
    # standard form or if it is in an invalid form. This doesn't raise errors.
    #
    def normalize_model(model)
      model = model.to_s if model.is_a?(Symbol)
      model = model.camelize.constantize rescue model if model.is_a?(String)
      model
    end

    #
    # Normalize and validate any acceptable forms for "model" parameters. If the
    # parameter is not in a valid form that represents a model class then an
    # ArgumentError is raised. Otherwise, the normalized form of the parameter
    # is returned (a Class instance for a class that has ActiveRecord::Base as
    # an ancestor).
    #
    def validate_model(model)
      result = normalize_model(model)
      raise ArgumentError, "invalid type for model: #{model.class}" unless result.is_a?(Class)
      raise ArgumentError, "invalid model: #{model.name}"           unless result.ancestors.include?(ActiveRecord::Base)
      result
    end

    #
    # Convert any acceptable forms for "column" parameters into a standard form,
    # namely a string. Returns the parameter as-is if it is already a string or
    # if it is in an invalid form. This doesn't raise errors.
    #
    def normalize_column(column)
      column.is_a?(Symbol) ? column.to_s : column
    end

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
    # validated using #validate_model above.
    #
    # Then, once a validated ActiveRecord model class is available and after the
    # column has been normalized, the model is used to ensure that the named
    # column exists in the table associated with the provided model. If not, an
    # exception is raised.
    #
    def validate_column(column, model = nil)
      model  = validate_model(model) if model
      result = normalize_column(column)
      raise ArgumentError, "invalid type for column: #{column.class} (#{column})" unless result.is_a?(String)
      raise ArgumentError, "invalid column: #{result}" if result.blank?
      raise ArgumentError, "invalid column: #{result} (not in table: #{model.table_name})" if
        model and !model.column_names.include?(result)
      result
    end

    #
    # Convert any acceptable forms for list of "columns" parameters into a
    # standard form, namely an array of strings. Returns the parameter as-is if
    # it is already in standard form or if it is in an invalid form. This
    # doesn't raise errors.
    #
    def normalize_columns(columns)
      result = []
      [columns].flatten.each do |c|
        c = normalize_column(c)
        if c.is_a?(String)
          result << c
        else
          return columns
        end
      end
      result
    end

    #
    # Normalize and validate any acceptable forms for list of "columns"
    # parameters. If the parameter is not in a valid form that represents a list
    # of one or more column (attribute) names on an ActiveRecord model class
    # then an ArgumentError is raised. Otherwise, the normalized form of the
    # parameter is returned (an array of strings).
    #
    # There are two possible validations: parital and complete. The differences
    # between them are identical and documented in the #validate_column
    # (singular) method above.
    #
    def validate_columns(columns, model = nil)
      model  = validate_model(model) if model
      result = normalize_columns(columns)
      raise ArgumentError, "invalid type for column list: #{columns.class} (#{columns})" unless result.is_a?(Array)
      result.each do |c|
        validate_column(c) # avoid re-validating model for each element
        raise ArgumentError, "invalid column: #{c} (not in table: #{model.table_name})" if
          model and !model.column_names.include?(result)
      end
      raise ArgumentError, "no columns provided" if result.empty?
      result
    end

    #
    # Tries to "guess" a model given a controller. You provide a controller (as
    # a symbol, string, or actual Class instance) and the controller's name is
    # used to try to come up with a model class.
    #
    # If successful, the model Class instance is returned. Otherwise nil is
    # returned. No exceptions are raised.
    #
    def model_from_controller(controller)
      controller = validate_controller(controller) rescue nil
      return nil unless controller
      name   = controller.name.demodulize
      prefix = controller.name.sub(Regexp.new(Regexp.escape(name) + "$"), "")
      validate_model(prefix + name.underscore.sub(/_controller$/, "").classify) rescue nil
    end


  ##############################################################################
  end # class << self
end   # module Axis

#
# Enable the Axis helper methods within rails...
#
require 'axis/enable'

