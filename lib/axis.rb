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
  autoload :Normalize,  'axis/normalize'
  autoload :State,      'axis/state'
  autoload :Version,    'axis/version'
  autoload :Validate,   'axis/validate'
  autoload :View,       'axis/view'
  autoload :Util,       'axis/util'
end
