# vim: fileencoding=utf-8:
require 'axis'
require 'rails'

module Axis
  #
  # TODO: Implement and document.
  #
  class Railtie < Rails::Railtie
    initializer 'rails-axis' do |app|
      ActiveSupport.on_load(:action_view) { ActionView::Base.send(:include, Axis::View) }
    end
  end
end
