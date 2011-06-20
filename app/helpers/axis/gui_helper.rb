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

    #
    # When rendering HTML elements for axis controls, you should use this helper
    # whenever you need to give an HTML element an id that is associated to a
    # specific axis binding.
    #
    # Provide the current axis state instance as the first parameter in order to
    # ensure the HTML element is "bound" to the associated binding. Then, for
    # the second parameter, provide the desired "id" string, sans any axis
    # prefix.
    #
    # Example: axis_id(state, "hi") => "axis-4-hi" # => binding #4's "hi" elem.
    #
    def axis_id(state, id = nil)
      "axis-#{state.id}" + (id ? "-#{id}" : "")
    end

    #
    # Form controls and link query-strings that perform axis actions should use
    # this helper to generate their parameter name string.
    #
    # Just provide the current bound state instance and then zero or more key
    # strings. The key string represent the nested hierarchical keys where said
    # parameter should exist in the final axis params hash.
    #
    # Example: axis_name(state, "filter", 3, "type")
    #   => "axis[2][filter][3][type]
    #   # binding #2's filter #3's "type" parameter
    #
    def axis_name(state, *keys)
      keys.flatten!
      result  = "axis[#{state.id}]"
      result += "[#{keys.shift}]" until keys.empty?
      result
    end

  end
end
