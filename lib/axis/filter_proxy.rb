# encoding: utf-8
module Axis
  class FilterProxy

    def initialize(attribute, state)
      raise ArgumentError, "invalid type for attribute: #{attribute.class}" unless attribute.is_a?(Attribute::Filter)
      raise ArgumentError, "invalid type for state: #{state.class}"         unless state.is_a?(State::Filter)
      @attribute = attribute
      @state     = state
    end

    #
    # Override ::Object's default #display to be an attribute reader...
    #
    def display
      @attribute.display
    end

    private

    def method_missing(name, *args, &block)
      begin
        return @attribute.send(name, *args, &block)
      rescue NoMethodError
      end
      @state.send(name, *args, &block)
    end

  end
end
