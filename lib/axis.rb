# vim: fileencoding=utf-8:
module Axis
  autoload :Attribute,  'axis/attribute'
  autoload :Binding,    'axis/binding'
  autoload :Controller, 'axis/controller'
  autoload :Model,      'axis/model'
  autoload :State,      'axis/state'
  autoload :Version,    'axis/version'
end

#
# Extend ActionController::Base and ActiveRecord::Base so our macro methods are
# available during controller and model class definition execution.
#
require 'action_controller'
require 'active_record'
ActionController::Base.send(:include, Axis::Controller)
ActiveRecord::Base.send(:include, Axis::Model)
