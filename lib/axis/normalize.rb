# vim: fileencoding=utf-8:
module Axis
  module Normalize

    #
    # Convert any acceptable forms for "controller" parameters into a standard
    # form, namely a Class instance. Returns the parameter as-is if it is
    # already in standard form or if it is in an invalid form. This doesn't
    # raise errors.
    #
    def controller(arg)
      result = arg.is_a?(Symbol) ? arg.to_s : arg
      if result.is_a?(String)
        result = result.camelize
        result = "#{result}Controller" unless result =~ /Controller\z/
        result = result.constantize rescue arg
      end
      result
    end
    module_function :controller

    #
    # Convert any acceptable forms for "action" parameters into a standard form,
    # namely a string. Returns the parameter as-is if it is already a string or
    # if it is in an invalid form. This doesn't raise errors.
    #
    def action(arg)
      arg.is_a?(Symbol) ? arg.to_s : arg
    end
    module_function :action

    #
    # Convert any acceptable forms for "model" parameters into a standard form,
    # namely a Class instance. Returns the parameter as-is if it is already in
    # standard form or if it is in an invalid form. This doesn't raise errors.
    #
    def model(arg)
      result = arg.is_a?(Symbol) ? arg.to_s : arg
      if result.is_a?(String)
        result = result.camelize.constantize rescue arg
      end
      result
    end
    module_function :model

    #
    # Convert any acceptable forms for "column" parameters into a standard form,
    # namely a string. Returns the parameter as-is if it is already a string or
    # if it is in an invalid form. This doesn't raise errors.
    #
    def column(arg)
      arg.is_a?(Symbol) ? arg.to_s : arg
    end
    module_function :column

    #
    # Convert any acceptable forms for list of "columns" parameters into a
    # standard form, namely an array of strings. Returns the parameter as-is if
    # it is already in standard form or if it is in an invalid form. This
    # doesn't raise errors.
    #
    def columns(arg)
      result = []
      [arg].flatten.each do |c|
        c = column(c)
        if c.is_a?(String)
          result << c
        else
          return arg
        end
      end
      result
    end
    module_function :columns

  end
end
