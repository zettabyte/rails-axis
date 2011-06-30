# encoding: utf-8
require 'bigdecimal'
require 'date'

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

    #
    # Convert any acceptable forms for a binding's "handle" parameter value into
    # a standard form, namely a string. Returns the parameter as-is if it is
    # already in standard form or if it is in an invalid form. This doesn't
    # raise errors.
    #
    def handle(arg)
      result = arg.is_a?(Symbol) ? arg.to_s : arg
      result.is_a?(String) ? result.gsub(/-/, "_") : arg
    end
    module_function :handle

    #
    # Convert any acceptable forms for an integer parameter into an actual
    # integer instance. Returns the parameter as-is if it is already an integer
    # or if it is in an invalid form. This doesn't raise errors.
    #
    def integer(arg)
      result = arg.is_a?(Symbol) ? arg.to_s : arg
      if result.is_a?(String)
        result = result =~ /\A-?\d+\z/ ? result.to_i : result
      end
      result.is_a?(Numeric) ? (result.to_i rescue arg) : arg
    end
    module_function :integer

    #
    # Convert any acceptable forms for a numeric parameter into an actual
    # Numeric instance. Returns the parameter as-is if it is already a numeric
    # object or if it is in an invalid form. This doesn't raise errors.
    #
    # Okay, the above isn't entirely true, this will try to normalize all Float
    # instances to BigDecimal instances instead.
    #
    def numeric(arg)
      percent = false
      result  = arg.is_a?(Symbol) ? arg.to_s : arg
      if result.is_a?(String)
        result = result.gsub(/[$,]/, "") # allow US currency in numerics
        if result =~ /%\z/
          result.sub!(/%\z/, "")
          percent = true
        end
        #
        # Just use Float() for format validation but use BigDecimal for actual
        # conversion (since Float() is picky but floats imprecise and BigDecimal
        # is precise but BigDecimal() is lenient)
        #
        begin ; Float(result)
        rescue ArgumentError ; return arg
        end
        result = Integer(result) rescue BigDecimal(result) rescue arg
      end
      result = result.is_a?(Float) ? BigDecimal(result) : result
      result.is_a?(Numeric) and percent ? result / BigDecimal("100.0") : result
    end
    module_function :numeric

    #
    # Convert any acceptable forms for a "temporal" parameter into an actual
    # Date, DateTime, or Time instance. Returns the parameter as-is if it is
    # already a "temporal" instance or if it is in an invalid form. This doesn't
    # raise errors.
    #
    # Okay, the above isn't entirely true, this will try to normalize all Time
    # and Date instances to DateTime instances instead.
    #
    def temporal(arg)
      result = arg.is_a?(Symbol) ? arg.to_s : arg
      result = DateTime.parse(result) rescue arg if result.is_a?(String)
      result = result.to_datetime                if result.is_a?(Time)
      result.is_a?(Date) ? result.to_datetime : result
    end
    module_function :temporal

    #
    # Convert any acceptable forms for an boolean parameter into a literal true
    # or false value. Returns the parameter as-is if it is already a boolean or
    # or if it is in an invalid form. This doesn't raise errors.
    #
    def boolean(arg)
      result = arg.is_a?(Symbol) ? arg.to_s : arg
      result = false if result.nil?
      if result.is_a?(String)
        result = case result
        when /\A(t(rue)?|y(es)?|on|-?1)\z/i then true
        when /\A(f(alse)?|no?|off|0)\z/i    then false
        else ; result ; end
      elsif result.is_a?(Numeric)
        result = result == 0 ? false : ((result == 1 or result == -1) ? true : result)
      end
      result.nil? ? false : result
    end
    module_function :boolean

  end
end
