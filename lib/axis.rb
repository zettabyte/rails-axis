# vim: fileencoding=utf-8:
module Axis
end

require 'action_controller'
ActionController::Base.send(:include, Axis::Controller)
