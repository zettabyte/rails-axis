# vim: fileencoding=utf-8:
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

    #
    # Manually create a binding with the provided type and association info.
    # Users must call Axis::Binding.bind in order to create instances since the
    # Axis::Binding.new method has been made private.
    #
    # You create a child binding by providing a "parent", otherwise it will be a
    # root binding. The scope is optional for root bindings but required for
    # child bindings.
    #
    # This DOES NOT do parameter validation (since it's private) but relies on
    # the public class method implementations to pre-validate all the arguments.
    #
    # The "type" must be one of the symbolds from the TYPES collection. The
    # "model" should be an ActiveRecord based model Class instance. The "scope"
    # is optional for root bindings. If provided it must be a string. On root
    # bindings that provide a scope, it must be the name of a named scope or
    # public class method on the model that acts like one. On child bindings,
    # scope is required and must be the name of a public instance method on the
    # model class of the child's parent binding (crystal clear?).
    #
    # For example, if you have a root binding bound to a User model and a child
    # of the root binding bound to a Post model, then the scope for the child
    # binding should be the name of a public instance method callable on User
    # instances. For example, if the User model "has_many :posts" then the
    # child's scope could be "posts" since you could send this message to a
    # User instance to get a set (a proxy on which we can further filter) of
    # Post instances.
    #
    # The "parent", if provided, must be another Binding instance. Not providing
    # a parent indicates a "root" binding. Therefor, you MUST NOT provide a
    # parent for root bindings (use nil) and MUST on child bindings.
    #
    # Finally, "name" is an optional alias that you may give this binding. Since
    # bindings are associated (not by their internal state but by where they're
    # stored) with a specific action of a specific controller (if you're a root
    # binding) or with a parent (if you're a child binding) and since, in each
    # case, there may be several "sibling" bindings, an alias must be unique
    # only amongst a binding's siblings.
    #
    def initialize(type, model, name = nil, scope = nil, parent = nil)
      @type     = type
      @model    = model
      @name     = name.freeze  if name
      @scope    = scope.freeze if scope
      @parent   = parent
      @children = [] # no kids yet
      @parent.adopt(self) if @parent
      register! # sets @id
    end

    attr_reader :id     # index of this instance in class-wide binding array
    attr_reader :type   # either :single or :set (one of TYPES)
    attr_reader :model  # reference to model class (Class instance)
    attr_reader :name   # alias or human-readable name (frozen string)
    attr_reader :scope  # name of scoping method (frozen string)
    attr_reader :parent # reference to another Binding instance (the parent)

    #
    # Get an array of all the child bindings belonging to this binding. The
    # returned array is a duplicate of the internal @children array so that
    # callers can't use this to modify the underlying collection (must use
    # the #adopt method).
    #
    def children
      @children.dup
    end

    def root?   ;  !@parent           end
    def child?  ; !!@parent           end
    def single? ;   @type == :single  end
    def set?    ;   @type == :set     end
    def parent? ;  !@children.empty?  end

    ############################################################################
    protected
    ############################################################################

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

    ############################################################################
    private
    ############################################################################

    #
    # Save reference to this binding in class-wide collection and save our index
    # in the collection to @id.
    #
    def register!
      @id  = nil
      (tmp = bindings).push(self)
      (0...tmp.length).reverse_each { |i| @id = i if tmp[i] == self }
      raise "Registration Error: Can't find self in class's bindings collection." unless @id
    end

    #
    # Provide instance-level access to class-level binding collection
    #
    def bindings
      self.class.instance_variable_get(:@bindings) || self.class.instance_variable_set(:@bindings, [])
    end

    ############################################################################
    class << self
    ############################################################################

      #
      # Provide access to our global collection of all created binding instances
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
        raise ArgumentError, "invalid type for options: #{options.class}" unless options.is_a?(Hash)
        create_binding(controller, action, options)
      end

      #
      # Convert any acceptable forms for a binding's "name" parameter value into
      # a standard form, namely a string. Returns the parameter as-is if it is
      # already in standard form or if it is in an invalid form. This doesn't
      # raise errors.
      #
      def normalize_name(name)
        name = name.to_s if name.is_a?(Symbol)
        name.is_a?(String) ? name.downcase.gsub(/_/, "-") : name
      end

      #
      # Normalize and validate any acceptable forms for a binding's "name"
      # parameter value. If the parameter is not in a valid form then an
      # ArgumentError is raised. Otherwise, the normalized form of the parameter
      # is returned (a string).
      #
      def validate_name(name)
        result = normalize_name(name)
        raise ArgumentError, "invalid type for name: #{name.class}" unless result.is_a?(String)
        raise ArgumentError, "invalid name: #{name}" unless result =~ /\A[a-z]([a-z0-9-]*[a-z0-9])?\z/
        result
      end

      #
      # Convert any acceptable forms for a binding's "type" parameter value into
      # a standard form, namely a symbol. Returns the parameter as-is if it is
      # already in standard form or if it is in an invalid form. This doesn't
      # raise errors.
      #
      def normalize_type(type)
        type.is_a?(String) ? type.intern : type
      end

      #
      # Normalize and validate any acceptable forms for a binding's "type"
      # parameter value. If the parameter is not in a valid form then an
      # ArgumentError is raised. Otherwise, the normalized form of the parameter
      # is returned (a symbol).
      #
      def validate_type(type)
        result = normalize_type(type)
        raise ArgumentError, "invalid type for binding type: #{type.class}" unless result.is_a?(Symbol)
        raise ArgumentError, "invalid binding type: #{type}" unless TYPES.include?(result)
        result
      end

      #
      # Convert any acceptable forms for a "parent" binding parameter value into
      # a standard form, namely an Axis::Binding instance. Returns the parameter
      # as-is if it is already in standard form or if it is in an invalid form.
      # This doesn't raise errors.
      #
      # The accepted forms are:
      # 1. Binding instance
      # 2. Integer (or equivalent numeric string or symbol) that is the "id" of
      #    a binding instance (can be looked up using: Axis::Binding[parent]).
      #
      def normalize_parent(parent)
        result = parent.is_a?(Symbol)                        ? parent.to_s  : parent
        result = result.is_a?(String) && result =~ /\A\d+\z/ ? result.to_i  : result
        result = result.is_a?(Fixnum) && self[result]        ? self[result] : result
        result.is_a?(self) ? result : parent
      end

      #
      # Normalize and validate any acceptable forms for a binding's "parent"
      # scope parameter value. If the parameter is not in a valid form then an
      # ArgumentError is raised. Otherwise, the normalized form of the parameter
      # is returned (an Axis::Binding instance).
      #
      def validate_parent(parent)
        result = normalize_parent(parent)
        raise ArgumentError, "invalid type for parent: #{parent.class}" unless result.is_a?(self)
        result
      end

      #
      # Convert any acceptable forms for a binding's "scope" parameter value
      # into a standard form, namely a string. Returns the parameter as-is if it
      # is already in standard form or if it is in an invalid form. This doesn't
      # raise errors.
      #
      def normalize_scope(scope)
        scope.is_a?(Symbol) ? scope.to_s : scope
      end

      #
      # Normalize and validate any acceptable forms for a binding's "scope"
      # parameter value. If the parameter is not in a valid form then an
      # ArgumentError is raised. Otherwise, the normalized form of the parameter
      # is returned (a string).
      #
      # There are two possible validations: partial and complete.
      #
      # ====== Partial Validation ======
      #
      # To do partial validation, just provide a single parameter (the scope).
      # In this instance, only the type of the parameter (and some other simple
      # constraints) are checked. It is not verified that any such method exists
      # within any ActiveRecord class (either the parent binding's or the
      # current binding's model) as it can't since it has no such ActiveRecord
      # model to check against.
      #
      # ====== Complete Validation ======
      #
      # To do complete validation, you must additionally provide either a valid
      # model (assumed to be the "current" binding's model) or parent binding in
      # addition to the scope. It will be validated that extra parameter is
      # indeed a valid model or parent binding as a side effect; be aware that
      # this will occur if you provide an extra parameter as it will either be
      # verified it refers to a parent binding or will be validated using the
      # Axis.validate_model method if it doesn't (in that order).
      #
      # Then, if you've got a valid model it is assumed we're validating the
      # scope for a root binding. The model will be used to ensure that the
      # scope exists as a public class method (or named scope) on the model.
      #
      # If, however, you've got a valid parent binding then it is assumed we're
      # validating a child binding. The parent binding will be used to ensure
      # that the scope exists as a public instance method (or ActiveRecord
      # relation) on the parent binding's model.
      #
      def validate_scope(scope, model_or_parent = nil)
        model = parent = nil
        if model_or_parent
          parent = normalize_parent(model_or_parent)
          model  = Axis.validate_model(model_or_parent) unless parent.is_a?(self)
        end
        result = normalize_scope(scope)
        raise ArgumentError, "invalid type for scope: #{scope.class}" unless result.is_a?(String)
        raise ArgumentError, "invalid scope: #{scope}" unless scope =~ /\A[a-z_]\w*\z/i
        if    model  # complete validation on root  binding: scope is class method on model
          raise ArgumentError, "invalid scope: #{scope} (not a class method on model)" unless
            model.public_methods.include?(result.intern)
        elsif parent # complete validation on child binding: scope is instance method on parent
          raise ArgumentError, "invalid scope: #{scope} (not an instance method in parent's model)" unless
            parent.model.public_instance_methods.include?(result.intern)
        end
        result
      end

      ##########################################################################
      private
      ##########################################################################

      #
      # Provide access to the class-level binding collection
      #
      def bindings
        @bindings ||= []
      end

      #
      # Provide access to the class-level associations hash: this, in reality,
      # is part of the binding configuration even though not stored as state
      # within the binding instances themselves. A binding is an associatio
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
        controller = Axis.normalize_controller(controller)
        action     = Axis.validate_action(action, controller).freeze
        @associations                     ||= {}
        @associations[controller]         ||= {}
        @associations[controller][action] ||= []
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
      # The options hash is guaranteed to be a valid hash by the caller. For
      # non-root calls, the controller, action, and parent are guaranteed to be
      # valid.
      #
      def create_binding(controller, action, options, parent = nil)
        root  = !parent         # is this the "root" call?
        type  = options[:type]  # validate later...
        scope = options[:scope] # ditto...
        name  = validate_name(options[:name])        if options[:name]
        model = Axis.validate_model(options[:model]) if options[:model]
        if root
          controller = Axis.normalize_controller(controller)
          action     = Axis.normalize_action(action)
          assoc      = associations(controller, action) # validates controller and action
          type     ||= (action == "index" ? :set : :single)
          model    ||= Axis.model_from_controller(controller)
          raise ArgumentError, "no model provided and unable to guess from controller" unless model
          if name and assoc.any? { |b| b.name == name }
            raise ArgumentError, "attempting to create two root bindings with the same name: #{name}"
          end
        else
          raise ArgumentError, "no scope provided in child-hash (require)" unless scope
        end
        children = [] # child options sub-hashes to be processed
        type     = validate_type(type           || :single)
        scope    = validate_scope(scope, parent || model) if scope
        raise ArgumentError, "no model provided in child-hash (required)" unless model

        #
        # Create this Binding and, if it is a root binding, associate it with
        # the provided controller/action...
        #
        result = new(type, model, name, scope, parent)
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
          create_binding(controller, action, child, result)
        end
        # Return this instance
        result
      end

    ############################################################################
    end # class << self
    ############################################################################

  end # class Binding
end   # module Axis

