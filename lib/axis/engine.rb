# encoding: utf-8
require 'axis'
require 'rails'

module Axis
  class Engine < Rails::Engine

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
