# vim: fileencoding=utf-8:
module Axis
  module Controller
    def self.included(base)
      base.send(:extend, ClassMethods)
    end
    module ClassMethods

      #
      # For each named controller action, create a binding (or full hierarchy of
      # bindings) using the provided options.
      #
      def axis_on(*args)
        options = args.extract_options!
        args    = args.flatten.map { |a| a.blank? ? nil : a }.compact.uniq
        args   << :index if args.empty?
        args.each do |action|
          ::Axis::Binding.bind(self, action, options)
        end
      end

    end
  end
end
