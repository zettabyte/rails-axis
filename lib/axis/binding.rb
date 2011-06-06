# vim: fileencoding=utf-8:
require 'axis/validate'
require 'axis/util'

module Axis

  #
  # Stores the information that links UI elements to a back-end data set.
  #
  # Binding instances are created as the application is being initialized and
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
  # Finally, every binding *must* be given a handle (a short name) that can be
  # used when using view helpers to "select" a given binding (well, to select or
  # create a State instance *associated* with the binding). The name can be
  # provided as a symbol or string. It must contain only "word" characters (the
  # "\w" regex character class) though it may also include dashes--they'll be
  # converted to underscores internally. A handle must be unique amongst all
  # bindings that are associated (directly as a root binding or indirectly as
  # a child) with a given controller/action pair.
  #
  class Binding
    include Enumerable
    private_class_method :new

    #
    # List of legal values for a Binding instance's #type
    #
    TYPES = [:single, :set].freeze

    #
    # Manually create a binding with the provided type and association info.
    # Users must call Binding.bind in order to create instances since the
    # Binding.new method has been made private.
    #
    # You create a child binding by providing a "parent", otherwise it will be a
    # root binding. The scope is optional for root bindings but required for
    # child bindings.
    #
    # This DOES NOT do parameter validation (since it's private) but relies on
    # the public class method implementations to pre-validate all the arguments.
    # The one exception to this is the "action" parameter. This doesn't validate
    # the action, but neither does the caller. Instead, the action will be
    # validated later when all bindings have #validate! called on them when the
    # Binding class has its first official lookup request.
    #
    # The "type" must be one of the symbols from the TYPES collection. The
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
    # The "handle" must be a string and must be unique amongst all the handles
    # for all bindings associated with the controller/action pair.
    #
    def initialize(controller, action, type, model, handle, scope = nil, parent = nil)
      @controller = controller
      @action     = action
      @type       = type
      @model      = model
      @handle     = handle.freeze
      @scope      = scope.freeze if scope
      @parent     = parent
      @children   = [] # no kids yet
      @parent.adopt(self) if @parent
      register! # sets @id
    end

    #
    # Canonical string form is combination of the controller, action, and handle
    # names joined together.
    #
    def to_s
      "#{@controller.name}##{@action}:#{@handle}"
    end

    #
    # Our "hash"-keying function based on our canonical string representation
    #
    def hash
      self.to_s.hash
    end

    #
    # Compare "hash"-key equality based on our canonical string representation
    #
    def eql?(other)
      self.to_s == other.to_s
    end

    #
    # Compare equality based on our canonical string representation
    #
    def ==(other)
      self.to_s == other.to_s
    end

    #
    # Sort based on our canonical string representation
    #
    def <=>(other)
      self.to_s <=> other.to_s
    end

    #
    # Prettier, more useful display of instance for debugging...
    #
    def inspect
      "<Binding[#{@id}](#{to_s}): " +
      "type=#{@type}, model=#{@model.name}, scope=#{@scope || "NONE"}, " +
      "root?=#{root? ? "true" : "false, parent=" + @parent.to_s}, " +
      "children?=#{parent?}>"
    end

    #
    # Called (once) on all created and registered bindings to do delayed
    # validation. All values are validated before the binding is created except
    # for the action name since you may create bindings before action methods
    # are defined when you call #axis_on in a controller before defining your
    # associated action methods. Run-on sentences are cool.
    #
    # So, this should validate the @action member.
    #
    def validate!
      Validate.action(@action, @controller)
    end

    attr_reader :id     # index of this instance in class-wide binding array
    attr_reader :type   # either :single or :set (one of TYPES)
    attr_reader :model  # reference to model class (Class instance)
    attr_reader :handle # string used to uniquely identify binding
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

    #
    # Get an array of all descendant bindings that are either children or
    # further descendants of this binding.
    #
    def descendants
      @children.map { |child| child.descendants }.flatten
    end

    def root?   ;  !@parent           end
    def child?  ; !!@parent           end
    def single? ;   @type == :single  end
    def set?    ;   @type == :set     end
    def parent? ;  !@children.empty?  end

    ############################################################################
    protected
    ############################################################################

    attr_reader :controller # the controller we're bound to
    attr_reader :action     # the action (on our controller) that we're bound to

    #
    # Request that this binding "adopts" the provided binding as its child. This
    # updates @children only after it has been validated that the child believes
    # this binding to be its parent.
    #
    def adopt(child)
      raise ArgumentError, "can't adopt child binding: it doesn't believe we're the parent" unless child.parent == self
      raise ArgumentError, "can't adopt child binding: its controller doesn't match ours"   unless @controller  == child.controller
      raise ArgumentError, "can't adopt child binding: its action doesn't match ours"       unless @action      == child.action
      raise ArgumentError, "can't adopt child binding: its handle already in use" if self.class.assoc(controller, action).include?(child)
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
      # Implement #each so we can expose an Enumerable interface over global
      # collection of all created binding instances
      #
      def each(&block)
        bindings.each(&block)
      end

      #
      # Retrieve a list (array) of all the "root" bindings on the controller and
      # action pair. An empty array is returned if the parameters are invalid or
      # there aren't any bindings for the pair.
      #
      def root(controller, action)
        read_only_associations(controller, action)
      end

      #
      # Retrieve a list (array) of ALL (both "root" and child) bindings on the
      # controller and action pair. An empty array is returned if the parameters
      # are invalid or there aren't any bindings for the pair.
      #
      def assoc(controller, action)
        result = read_only_associations(controller, action)
        result + result.map { |b| b.descendants }.flatten
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
      # Provide access to the class-level associations hash. This accessor gives
      # you access only to the list of root-level bindings for the provided
      # controller and action. Assumes parameters are valid an thus, if the
      # associated entries don't yet exist for the controller/action, then they
      # are created an a new, "registered" empty array is returned that the
      # caller may use to add or register new "root" bindings.
      #
      def associations(controller, action)
        @associations                     ||= {}
        @associations[controller]         ||= {}
        @associations[controller][action] ||= []
      end

      #
      # This is similar to #associations above but it validates the provided
      # controller and normalizes the action. Then, is does a passive look-up
      # using the pair, NOT creating entries if there aren't any yet for the
      # controller or action in their associated hashes.
      #
      # Finally, it returns a COPY of the array of references to all the root
      # bindings for the controller/action pair (if they're valid and such an
      # array exists--even if its empty still). If validation fails or either
      # there aren't any entires for the controller or action, then an empty
      # array is returned.
      #
      # Either way, at least an empty array is returned. Also, either way, the
      # array is at best a copy so you can't use the return value to "register"
      # entries in the associations collections. Thus, this is a "read only"
      # version of #assoctions above.
      #
      def read_only_associations(controller, action)
        controller = Validate.controller(controller) rescue nil
        action     = Normalize.action(action)
        return [] unless controller and action and @associations
        return [] unless @associations[controller]
        return [] unless @associations[controller][action]
        @associations[controller][action].dup
      end

      #
      # Convert any acceptable forms for a binding's "handle" parameter value
      # into a standard form, namely a string. Returns the parameter as-is if it
      # is already in standard form or if it is in an invalid form. This doesn't
      # raise errors.
      #
      def normalize_handle(handle)
        result = handle.is_a?(Symbol) ? handle.to_s : handle
        result.is_a?(String) ? result.gsub(/-/, "_") : handle
      end

      #
      # Normalize and validate any acceptable forms for a binding's "handle"
      # parameter value. If the parameter is not in a valid form then an
      # ArgumentError is raised. Otherwise, the normalized form of the parameter
      # is returned (a string).
      #
      def validate_handle(handle)
        result = normalize_handle(handle)
        raise ArgumentError, "invalid type for handle: #{handle.class}" unless result.is_a?(String)
        raise ArgumentError, "invalid handle: #{handle}" if result =~ /[^\w]/
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
      # Validate.model method if it doesn't (in that order).
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
          model  = Validate.model(model_or_parent) unless parent.is_a?(self)
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
        root   = !parent         # is this the "root" call?
        type   = options[:type]  # validate later...
        scope  = options[:scope] # ditto...
        handle = validate_handle(options[:handle])
        model  = Validate.model(options[:model]) if options[:model]
        if root
          controller = Validate.controller(controller)
          action     = Normalize.action(action)
          type     ||= (action == "index" ? :set : :single)
          model    ||= Util.model_from_controller(controller)
          raise ArgumentError, "no model provided and unable to guess from controller" unless model
        else
          raise ArgumentError, "no scope provided in child-hash (require)" unless scope
        end
        if assoc(controller, action).any? { |b| b.handle == handle }
          raise ArgumentError, "attempting to create two bindings with the same handle: #{handle}"
        end
        children = [] # child options sub-hashes to be processed
        type     = validate_type(type           || :single)
        scope    = validate_scope(scope, parent || model) if scope
        raise ArgumentError, "no model provided in child-hash (required)" unless model

        #
        # Create this Binding and, if it is a root binding, associate it with
        # the provided controller/action...
        #
        result = new(controller, action, type, model, handle, scope, parent)
        associations(controller, action) << result if root

        #
        # process any :child or :children options...
        #
        children << options[:child] if options[:child].is_a?(Hash)
        if options[:children].is_a?(Array)
          children += options[:children]
        elsif options[:children].is_a?(Hash)
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

