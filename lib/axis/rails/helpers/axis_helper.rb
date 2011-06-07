# vim: fileencoding=utf-8:
module Axis
  module View

    #
    #
    def axis_table(*args)
      options = args.extract_options!
      binding = Binding.load(controller_name, action_name, *args)
      raise ArgumentError, "invalid selectors" unless binding
      "<table border='0' cellpadding='0' cellspacing='0'></table>".html_safe
    end

  end # module Model
end   # module Axis
