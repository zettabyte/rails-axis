# encoding: utf-8
module Axis
  module GuiHelper

    #
    # Render the standard search panel
    #
    def axis_search(*args, &block)
      options = args.extract_options!
      handle  = args.shift || options[:handle]
      render :partial => "axis/search", :object => controller.axis_state(handle), :as => :axis
    end

    #
    # Render the standard record-table panel
    #
    def axis_table(*args, &block)
      options = args.extract_options!
      handle  = args.shift || options[:handle]
      render :partial => "axis/table", :object => controller.axis_state(handle), :as => :axis
    end

    #
    # Render both a search panel and a record-table panel
    #
    def axis_panel(*args, &block)
      axis_search(*args, &block) + axis_table(*args, &block)
    end

  end
end
