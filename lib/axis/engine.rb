# vim: fileencoding=utf-8:
require 'axis'
require 'rails'

module Axis
  class Engine < Rails::Engine

    #
    # Location of our view helpers and view templates...
    #
    paths.app.helpers = "lib/axis/rails/helpers"
    paths.app.views   = "lib/axis/rails/views"

    #
    # Extend ActiveRecord::Base and ActionController::Base with our axis macro
    # methods...
    #
    initializer 'rails-axis' do |app|
      ActiveSupport.on_load(:active_record)     { include Axis::Model      }
      ActiveSupport.on_load(:action_controller) { include Axis::Controller }
    end

  end
end
