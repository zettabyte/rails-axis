# vim: fileencoding=utf-8:
module Axis
  module Controller
    def self.included(base)
      base.send(:extend, ClassMethods)
    end
    module ClassMethods

      def axis_on(*args)
        settings = axis_settings
        options  = process_axis_options(args.extract_options!)
        args     = args.flatten.map { |a| a.blank? ? nil : a.to_s }.compact.uniq
        args    << "index" if args.empty?
        args.each { |a| settings[a] = options }
      end

      private

      def axis_settings
        @axis       ||= {} # global axis settings hash
        @axis[self] ||= {} # w/settings grouped by controller
      end

      #
      # Determine a potential "model" name based on this controller's name
      #
      def axis_guess_model_name
        name   = self.name.demodulize
        prefix = self.name.sub(Regexp.new(Regexp.escape(name) + "$"), "")
        prefix + name.underscore.sub(/_controller$/, "").classify
      end

      #
      # Recursively process options passed to #axis_on (above). Callers should
      # always rely on the default parameter value (true) for the optional
      # "root" argument (the caller *is* issuing the "root" call).
      #
      # Returns a processed and validated settings hash (where any values such
      # as strings have been duplicated). Raises ArgumentError if invalid option
      # values are encountered and ignores unrecognized options.
      #
      def process_axis_options(options, root = true)
        children = nil
        settings = {}

        #
        # Determine the axis model...
        #
        settings[:model] = case options[:model]
        when Symbol        then options[:model].to_s
        when String        then options[:model].dup
        when Class         then options[:model].name
        when NilClass
          if root
            axis_guess_model_name
          else
            raise ArgumentError, "child option hashes *must* have a :model option"
          end
        else
          raise ArgumentError, "invalid type for :model option: #{options[:model].class.name}"
        end
        begin
          settings[:model] = settings[:model].constantize
        rescue NameError => e
          if options[:model]
            raise ArgumentError, "invalid value for :model option (uninitialized constant #{settings[:model]})"
          else
            raise ArgumentError, "couldn't guess model name; :model option required (guessed: #{settings[:model]})"
          end
        end

        #
        # Determine the axis scope...
        #
        settings[:scope] = case options[:scope]
        when Symbol        then options[:scope]
        when String        then options[:scope].intern
        when NilClass      then :all
        else
          raise ArgumentError, "invalid type for :scope option: #{options[:scope].class.name}"
        end
        unless settings[:model].respond_to?(settings[:scope])
          raise ArgumentError, "invalid value for :scope option: #{settings[:scope]} " +
            "(model class #{settings[:model].name} has no such :scope or class method)"
        end

        #
        # Do some validation of any :child or :children options...
        #
        if options.has_key?(:children) and options.has_key?(:child)
          raise ArgumentError, "you may not specify both :child and :children options (pick one)"
        end
        if options.has_key?(:child)
          unless options[:child].is_a?(Hash)
            raise ArgumentError, "invalid type for :child option: #{options[:child].class.name} (must be a hash)"
          end
          children = [options[:child]]
        elsif options.has_key?(:children)
          if options[:children].is_a?(Hash)
            children = [options[:children]]
          elsif options[:children].is_a?(Array)
            children = options[:children].flatten.compact
            children = nil if children.empty?
          else
            raise ArgumentError, "invalid type for :children option: #{options[:children].class.name} (must be hash or array of hashes)"
          end
        end

        #
        # Process any :child or :children settings and return results
        #
        if children
          settings[:children] = []
          children.each do |child|
            unless child.is_a?(Hash)
              raise ArgumentError, "invalid entry in :children option's array: #{child.class.name} (must be a hash)"
            end
            settings[:children] << process_axis_options(child, false)
          end
        end
        settings
      end

    end
  end
end
