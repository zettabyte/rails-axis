# vim: fileencoding=utf-8:
require 'axis'
require 'rails'

module Axis
  class Railtie < Rails::Railtie
    initializer 'rails-axis' do |app|
      ActiveSupport.on_load(:active_record)     { include Axis::Model      }
      ActiveSupport.on_load(:action_view)       { include Axis::View       }
      ActiveSupport.on_load(:action_controller) { include Axis::Controller }
    end
  end
end
