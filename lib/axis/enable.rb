# vim: fileencoding=utf-8:

#
# Require this file (require 'axis/enable') after pulling in the main axis
# module (require 'axis') in order to manually force the extending of various
# rails types. You DO NOT normally need this as the default entry in your rails
# application's Gemfile, coupled with the railtie activation will do this when
# rails is loaded.
#
# However, if you're running outside the context of a normal, activated rails
# application and you want to manually "activate" these extension then this is
# the file to "require".
#
require 'action_controller'
require 'active_record'
ActionController::Base.send(:include, Axis::Controller)
ActiveRecord::Base.send(:include, Axis::Model)
