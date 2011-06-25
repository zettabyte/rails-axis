# encoding: utf-8
module Axis
  module GuiHelper

    #
    # Render the standard search panel for the specified form
    #
    def axis_search(*args, &block)
      options = args.extract_options!
      handle  = args.shift || options[:handle]
      form    = axis.form(handle)
      render :partial => "axis/search", :object => form, :as => :form
    end

    #
    # Render the standard record-table panel for the specified form
    #
    def axis_table(*args, &block)
      options = args.extract_options!
      handle  = args.shift || options[:handle]
      form    = axis.form(handle)
      render :partial => "axis/table", :object => form, :as => :form
    end

    #
    # Render both a search panel and a record-table panel for the specified form
    #
    def axis_panel(*args, &block)
      axis_search(*args, &block) + axis_table(*args, &block)
    end

  end
end
