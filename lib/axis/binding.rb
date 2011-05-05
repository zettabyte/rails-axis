# vim: fileencoding=utf8:
module Axis

  #
  # Stores the information that links UI elements to a back-end data set.
  #
  # Binding instances are created as the application is initialized and
  # controller class definitions are executed. They are then persisted for the
  # duration of the application and comprise part of the runtime configuration.
  #
  # Instances are defined and created by calls to the #axis_on controller macro.
  # One instance is created per action defined within a given call. A binding is
  # thus associated with a specific action of a specific controller. A given
  # action may actually have several "root" or "top-level" bindings associated
  # with it.
  #
  # Likewise, just as the #axis_on controller macro may contain nested config.
  # definitions, each nested level creates another binding (associated with the
  # same action) where the binding is a "child" binding that refers to its
  # "parent" binding. A "root" binding is one with no parent, it is directly
  # associated with a controller's action.
  #
  # On the other end, a binding is associated with a data model (specifically
  # one of your "model" classes). The binding itself doesn't associate with a
  # specific record or set of records that are managed by the model class, but
  # it *may* be associated with a class method or named scope within the model
  # class. Likewise, a binding *may* store an association to an instance method
  # (or model association like those created by #has_many and #belongs_to).
  #
  # Bindings come in two flavors, one that is designed to associate UI elements
  # with a single record in the associated model, and one that is designed to
  # associate the UI to an entire set of records managed by the model class.
  # Thus, the #type of a binding may be either :single or :set respectively.
  #
  # Top-level or "root" bindings will have no "parent" defined (#parent returns
  # nil). Child bindings must refer to another binding that has already been
  # created as its parent. Thus a set of bindings may be constructed into a
  # N-ary tree with the whole tree associated to the same action. An action may
  # therefor have several separate trees of bindings associated with it.
  #
  # Bindings may optionally be given a "name" or "alias" a short, textual name
  # (with only letters, digits, the underscore and/or hyphens; for purposes of
  # comparison, it is case-insensitive and hyphens and underscores are treated
  # as being identical). An alias must be unique only amongst other "sibling"
  # bindings, such as those that all have the same parent or the set of all
  # "root" bindings for a given action. A binding's alias makes serialized
  # references to a specific binding more human readable. These "serialized"
  # references may show up within query parameters in generated URLs, hence the
  # ability to "pretty them up" a bit.
  #
  class Binding
    private_class_method :new

    #
    # List of legal values for a Binding instance's #type
    #
    TYPES = [:single, :set].freeze

    class << self
      #
      # Provide access to our global collection of all created binding instances.
      #
      def [](index)
        bindings[index]
      end

      #
      # Public interface for creating "bindings" or associations between a model
      # (and possibly a scoping method) and a controller's action. This is
      # done (called) by the #axis_on controller macro method that's mixed into
      # ActionController via the Axis::Controller::ClassMethods module.
      #
      # The "controller" must be an ActionController::Base subclass that
      # contains "action" (string or symbol) which is the the name of a method
      # defined by the controller class. The "options" is a hash that defines
      # what gets bound to the specified controller/action.
      #
      # The supported options are fully documented in
      # Axis::Controller::ClassMethods#axis_on as that method passes its options
      # through to this one.
      #
      def bind(controller, action, options)
        create_binding(controller, action, options)
      end

      #
      # Validates and normalizes the proposed binding name or alias. This will
      # NOT raise exceptions, it just returns nil if the name is invalid and a
      # string (normalized form of the name) if it *is* valid.
      #
      # To be valid, the provided name must be a symbol or string. The
      # "normalization" process will convert all uppercase letters to lowercase
      # and all underscores to hyphens (ASCII 0x2D). It goes without saying that
      # it converts symbols to their string equivalents first.
      #
      # Finally, for a name to be valid, it must meet the following conditions
      # (after being normalized):
      #   - 1 or more characters long
      #   - start with lowercase letter
      #   - end with lowercase letter or digit
      #   - may otherwise include any number of:
      #     - lowercase letters
      #     - digits (0-9)
      #     - dashes "-"
      #
      def validate_name(name)
        return nil unless name.is_a?(String) or name.is_a?(Symbol)
        name = name.to_s.downcase.gsub(/_/, "-")
        name =~ /\A[a-z]([a-z0-9-]*[a-z0-9])?\z/ ? name : nil
      end

    end

    #
    # Manually create a binding with the provided type and association info.
    # Users must call Axis::Binding.bind in order to create instances since the
    # Axis::Binding.new method has been made private.
    #
    # You create a child binding by providing a "parent", otherwise it will be a
    # root binding. The scope is optional for root bindings but required for
    # child bindings.
    #
    # The "type" must be a string or symbol that corresponds to one of the
    # values in the TYPES collection. They are:
    #   :single => this binding is designed to bind one record at a time
    #   :set    => this binding is designed to bind a set of records at a time
    #
    # The "model" is the class (should be a model class that controls access to
    # underlying data "record" objects) that this binding binds to. You may
    # provide the actual Class instance or just the name of the class (as a
    # string or symbol). If the class is namespaced, you must provide the full
    # name.
    #
    # The "scope" (optional for root bindings) must be the name of a method as a
    # string or symbol. For root bindings, this must be a public class method on
    # the model class. The method must be or act like an active record "named
    # scope" in that it "filters" the set of available records managed by the
    # model class, returning a "proxy" object that represents a subset of the
    # total available records and on which you can apply futher "filtering"
    # operations. If not provided on root bindings, then the binding starts by
    # operating on or binding to "all" records managed by the model.
    #
    # For child bindings, "scope" is required and must refer to a public
    # instance method on the model class of the child's "parent" binding. Since
    # a binding, once combined with a State instance, defines the concept of a
    # "current" record (whether the binding is :single or :set) then a child's
    # "scope" is used to get the set of records of its model class that are
    # associated with its parent's "current record" of its model class. So, if
    # the parent binds to a User model and the child a Post model, then the
    # "scope" should be a method (such as those created by active record's
    # #has_many relationship macro method) on a User instance that returns a
    # set (or a proxy object representing a set) of Post instances. In this
    # example (using active record) if a user "has_many" posts, then the child
    # binding may be :posts.
    #
    # The "parent", if provided, must be another Binding instance. It may
    # optionally be the numeric "id" of an existing Binding instance (as
    # returned by #id) such that Binding[parent] may be used to get a reference
    # to the desired instance.
    #
    # Finally, "name" is an optional alias that you may give this binding. Since
    # bindings are associated (not by their internal state but by where they're
    # stored) with a specific action of a specific controller (if you're a root
    # binding) or with a parent (if you're a child binding) and since, in each
    # case, there may be several "sibling" bindings, an alias must be unique
    # only amongst a binding's siblings.
    #
    # NOTE: When talking about scopes, the result of calling the referred to
    #       scope method should, for :set bindings return some kind of proxy
    #       instance on which the model's underlying ORM may be used to further
    #       filter the set using an axis search panel. However, for :single
    #       bindings, a scope should ideally return a single instance of the
    #       desired model. It may return an array of instances or a proxy object
    #       representing several instances though; the first instance will be
    #       assumed/used in this case. For a root binding that is a :single
    #       binding, if no scope is provided then at runtime the main record
    #       identifyer (primary key for active record) is stored in the state
    #       and used to load the single instance. However, a :single root
    #       binding *with* a scope allows you to control what identifying data
    #       or fields get cached in a runtime state object by having a class
    #       method that can uniquely load a single instance using said data.
    #
    def initialize(type, model, scope = nil, parent = nil, name = nil)
      #
      # Validate and normalize the type, model, scope and parent.
      #
      @type   = validate_type(type)
      @model  = validate_model(model)
      @parent = validate_parent(parent)
      @scope  = validate_scope(scope)
      @name   = validate_name(name)

      #
      # Complete the birth process by telling our parent about ourselves, noting
      # that we have no children yet, and registering with the authorities.
      #
      @children = [] # no kids yet
      @parent.adopt(self) if @parent
      register!
    end

    attr_reader :id     # index of this instance in class-wide binding array
    attr_reader :type   # either :single or :set (one of TYPES)
    attr_reader :model  # reference to model class (Class instance)
    attr_reader :parent # reference to another Binding instance (the parent)
    attr_reader :scope  # name of scoping method (symbol)
    attr_reader :name   # alias or human-readable name for binding (string)

    #
    # Query if this represents a "root" or "top-level" binding or not
    #
    def root?
      !@parent
    end

    #
    # Query if this represents a "child" binding or not
    #
    def child?
      !!@parent
    end

    #
    # Query if this binding's type is :single or not
    #
    def single?
      @type == :single
    end

    #
    # Query if this binding's type is :set or not
    #
    def set?
      @type == :set
    end

    #
    # Query if this binding has any children or not
    #
    def parent?
      !@children.empty?
    end

    #
    # Get an array of all the child bindings belonging to this binding. The
    # returned array is a duplicate of the internal @children array so that
    # callers can't use this to modify the underlying collection (must use
    # the #adopt method).
    #
    def children
      @children.dup
    end

    protected

    #
    # Request that this binding "adopts" the provided binding as its child. This
    # updates @children only after it has been validated that the child believes
    # this binding to be its parent and that its name, if it has one, is unique
    # amongst any existing children.
    #
    def adopt(child)
      raise ArgumentError, "can't adopt child binding: it doesn't believe we're the parent" unless child.parent == self
      if child.name and @children.any? { |b| child.name == b.name }
        raise ArgumentError, "child binding name not unique amongst siblings: #{child.name}"
      end
      @children << child
      nil # don't hand out reference to our collection of kids
    end

    private

    #
    # Validate that the argument is a legit value for a binding's "type". The
    # type must match one of the values in the TYPES collection and may be a
    # string or symbol. Returns the type normalized into symbol form.
    #
    def validate_type(type)
      result = type.intern if type.is_a?(String)
      raise ArgumentError, "invalid binding type: #{type} (#{type.class})" unless TYPES.include?(result)
      result
    end

    #
    # Validate that the argument is a legit reference to a model class (either
    # a string, symbol, or an actual model Class instance). If it *is* legit,
    # normalize it into an actual reference to the model class (Class instance).
    #
    def validate_model(model)
      return model if model.is_a?(Class)
      result = nil
      if model.is_a?(String) or model.is_a?(Symbol)
        result = model.to_s.camelize.constantize rescue nil
      end
      raise ArgumentError, "invalid model: #{model} (#{model.class})" unless result
      result
    end

    #
    # Validate that the argument is a legit reference to another Binding object,
    # either a an actual reference or as an "id" number that matches an existing
    # instance in the Binding[] collection. Returns the parent normalized into
    # an actual object reference.
    #
    def validate_parent(parent)
      if parent.nil?
        nil # being explicit for clarity: this is a root binding (nil legal)
      else
        result   = Binding[parent] rescue nil
        result ||= parent
        raise ArgumentError, "invalid parent: #{parent} (#{parent.class})" unless result.is_a?(self.class)
        result
      end
    end

    #
    # Must be called _after_ @type, @model, and @parent have been initialized
    # and normalized (by their respective validation methods).
    #
    # Validates that the argument is a legit "scope" for this binding. A scope
    # must be a method name in string or symbol form (the kind of method, class
    # or instance, and on which class or instance depends on whether this is a
    # root or child binding). Returns the scope normalized into symbol form.
    #
    def validate_scope(scope)
      if scope.nil?
        raise ArgumentError, "child bindings require a scope (none provided)" if @parent
        nil
      else
        result = scope.to_s.intern
        if @parent # we're a child: scope is instance method or association
          result = nil unless @parent.model.public_instance_methods.include?(result)
        else # we're a root binding: scope is class method or named scope
          result = nil unless @model.public_methods.include?(result)
        end
        raise ArgumentError, "invalid scope: #{scope} (#{scope.class})" unless result
        result
      end
    end

    #
    # Validates that the argument is a legit alias for this binding. See the
    # class method of the same name for details. This DOES NOT validate
    # uniqueness amongst siblings. This is done at a higher level within the
    # class method #create_binding which does this for all root bindings and
    # indirectly for children via the #adopt method.
    #
    def validate_name(name)
      result = self.class.validate_name(name)
      raise ArgumentError, "invalid name/alias: #{name} (#{name.class})" unless result
      result.freeze
    end

    #
    # Save reference to this binding in class-wide collection and save our index
    # in the collection to @id.
    #
    def register!
      @id  = nil
      (tmp = bindings).push(self)
      (0...tmp.length).reverse_each do |i|
        @id = i if tmp[i] == self
      end
      raise "Registration Error: Can't find self in class's bindings collection." unless @id
    end

    #
    # Provide instance-level access to class-level binding collection
    #
    def bindings
      self.class.instance_variable_get(:@bindings) || self.class.instance_variable_set(:@bindings, [])
    end

    class << self
      private

      #
      # Provide access to the class-level binding collection
      #
      def bindings
        @bindings ||= []
      end

      #
      # Provide access to the class-level associations hash: this, in reality,
      # is part of the binding configuration even though not stored as state
      # within the binding instances themselves. A binding is an association
      # between a specific action on a specific controller and a model. Thus,
      # this stores half that information, namely it associates a specific
      # action on a specific controller with a binding instance (which itself
      # stores the reference to a model class).
      #
      # The associations returned is a hash where the keys are controller
      # classes (Class instances that have inherited from ActionController::Base
      # somewhere in their ancestry). For each entry, the value is yet another
      # (nested) hash.
      #
      # The nested hash has, for keys, symbols that correspond to a specific
      # action in the associated controller. The value for each entry will be
      # an array. Each innermost value array contains one or more references to
      # Axis::Binding instances. Each such reference denotes (and therefor must
      # reference) a root binding that is associated with the action on the
      # associated controller.
      #
      # This accessor gives you access only to the list of root-level bindings
      # for the provided controller and action. This *does* validate that the
      # controller and action are legitimate, raising ArgumentError if not.
      #
      def associations(controller, action)
        raise ArgumentError, "invalid controller: #{controller} (#{controller.class})" unless controller.is_a?(Class)
        raise ArgumentError, "invalid action: #{action} (#{action.class})" unless action.is_a?(String) or action.is_a?(Symbol)
        raise ArgumentError, "#{controller} isn't descended from ActionController::Base" unless controller.ancestors.include?(ActionController::Base)
        raise ArgumentError, "#{action} isn't a method on #{controller}" unless controller.public_instance_methods.include?(action.intern)
        @associations                     ||= {}
        @associations[controller]         ||= {}
        @associations[controller][action] ||= []
      end

      #
      # Determine a potential "model" name based on a controller's name
      #
      def guess_model(controller)
        name   = controller.name.demodulize
        prefix = controller.name.sub(Regexp.new(Regexp.escape(name) + "$"), "")
        prefix + name.underscore.sub(/_controller$/, "").classify
      end

      #
      # Recursive implementation of the public #bind method (Axis::Binding.bind)
      #
      # The original caller (#bind) uses the default value (nil) for the parent
      # parameter, denoting the original/root call. This results in a hierarchy
      # of bindings being created by using recursive calls such that each call
      # creates a single binding. The values supported by the options hash are
      # documented in the Axis::Controller::ClassMethods#axis_on description.
      #
      # Returns the binding that was created (the root binding in the case of
      # the root call).
      #
      def create_binding(controller, action, options, parent = nil)
        root     = !parent # is this the "root" call?
        children = []      # child options sub-hashes to be processed
        type     = options[:type] || ((root && action == :index) ? :set : :single)
        model    = options[:model]
        model  ||= guess_model_name(controller) if root
        name     = validate_name(options[:name])

        #
        # Create this Binding (validates parameters) and, if it is a root
        # binding, associate it with the provided controller/action...
        #
        assoc = associations(controller, action) if root
        if root and name and assoc.any? { |b| b.name == name }
          raise ArgumentError, "attempting to create two root bindings with the same name: #{name}"
        end
        result = new(type, model, options[:scope], parent, name)
        assoc << result if root

        #
        # process any :child or :children options...
        #
        children << options[:child] if options[:child].is_a?(Hash)
        if options[:children].is_a?(Array)
          children += options[:children]
        elsif option[:children].is_a?(Hash)
          children << options[:children]
        end
        children.flatten.compact.each do |child|
          unless child.is_a?(Hash)
            raise ArgumentError, "invalid entry in :children option's array: #{child.class} (must be a hash)"
          end
          create_binding(controller, action, child, result, assoc)
        end

        # Return this instance
        result
      end

    end # class << self ; private

  end # class Binding
end   # module Axis
