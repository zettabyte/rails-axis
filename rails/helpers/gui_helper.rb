# encoding: utf-8
module Axis
  module GuiHelper

    #
    # Render the standard search panel
    #
    def axis_search(*args, &block)
      #render :partial => "search", :locals => { "binding" => #TODO
    end

    #
    # Render the standard record-table panel
    #
    def axis_table(*args, &block)
      options = args.extract_options!
      "<table border='0' cellpadding='0' cellspacing='0'></table>".html_safe
    end

  end
end
