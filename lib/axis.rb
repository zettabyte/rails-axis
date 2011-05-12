# vim: fileencoding=utf-8:
module Axis
end

#
# Extend ActionController::Base and ActiveRecord::Base so our macro methods are
# available during controller and model class definition execution.
#
require 'action_controller'
require 'active_record'
require 'axis/controller'
require 'axis/model'
ActionController::Base.send(:include, Axis::Controller)
ActiveRecord::Base.send(:include, Axis::Model)
