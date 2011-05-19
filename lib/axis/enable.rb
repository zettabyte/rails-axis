# vim: fileencoding=utf-8:

#
# Extend various rails types in order to enable the various Axis helper methods.
#
require 'action_controller'
require 'active_record'
ActionController::Base.send(:include, Axis::Controller)
ActiveRecord::Base.send(:include, Axis::Model)
