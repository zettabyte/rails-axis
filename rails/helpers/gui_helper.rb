# encoding: utf-8
module Axis
  module GuiHelper

    #
    # Render the standard search panel
    #
    def axis_search(*args, &block)
      #render :partial => "search", :locals => { "binding" => #TODO
      "<h4>Search</h4>".html_safe
    end

    #
    # Render the standard record-table panel
    #
    def axis_table(*args, &block)
      options = args.extract_options!
      "<table border='0' cellpadding='0' cellspacing='0'></table>".html_safe
    end

    #
    # Render both a search panel and a record-table panel
    #
    def axis_panel(*args, &block)
      axis_search(*args, &block) + axis_table(*args, &block)
    end

  end
end
