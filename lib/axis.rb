# encoding: utf-8

#
# This is the base module for the Axis rails gem.
#
module Axis
  autoload :Attribute,  'axis/attribute'
  autoload :Binding,    'axis/binding'
  autoload :Controller, 'axis/controller'
  autoload :Model,      'axis/model'
  autoload :Normalize,  'axis/normalize'
  autoload :Session,    'axis/session'
  autoload :State,      'axis/state'
  autoload :Version,    'axis/version'
  autoload :Validate,   'axis/validate'
  autoload :View,       'axis/view'
  autoload :Util,       'axis/util'
end

require 'axis/engine' if defined?(Rails::Engine)
