# vim: fileencoding=utf-8:

module Axis

  #
  # Instances of this class represent either a "literal" or "logical" attribute
  # within an associated model class. They store metadata about an literal data
  # column or about a "logical" one so that other parts of the Axis library will
  # know what attributes should be displayed, which ones can be used to sort a
  # result set, if you can filter on the attribute and how to do so.
  #
  # This is perhaps the heart of the entire Axis system.
  #
  # Each attribute may be a "literal" or "logical" attribute. A "literal" simply
  # stores metadata about a specific data field in the associated model. Thus it
  # "enriches" the metadata already available through the model class itself. A
  # "logical" attribute in essence defines a new (logical) data field that is
  # now available through the model class. The logical attributes may be an
  # abstraction, transformation, or aggregation of one or more back-end model
  # data fields. Logical attributes include code that knows how to combine or
  # otherwise transform the data fields into a new, single data type in addition
  # to the metadata that all Axis attributes store.
  #
  class Attribute

    autoload :Filter, 'axis/attribute/filter'
    autoload :Sort,   'axis/attribute/sort'

    #
    # The keys of this hash are the official Axis attribute types. The Axis
    # library is more general even than ORMs like ActiveRecord; its types are
    # more like broad categories of the types defined by ActiveRecord.
    #
    # The value associated with each key is a list of the ActiveRecord types
    # that are considered to be within or equivalent to the Axis type. It is
    # expected that users calling methods that define Axis attribute information
    # within a model will use one of these ActiveRecord types. As such, they are
    # "first-class" aliases for the official Axis types (the keys). Also, in
    # most, if not all instances, when defining logical columns the type is
    # pulled from ActiveRecord's knowledge of column types anyway.
    #
    # The "first-class" designation simply means that an Axis::Attribute's type
    # won't be normalized away from any such first-class aliases, even though it
    # is just an alias for a broad category as far as Axis is concerned.
    #
    # Thus, if querying an Axis::Attribute instance for its type, you may, for
    # instance, get :integer, :float, or :decimal as an answer in addition to
    # :numeric, depending on how the attribute was defined by the user in their
    # model class. All these results, however, designate a :numeric attribute.
    #
    TYPES = {
      :string   => [:string, :text].freeze,
      :binary   => [:binary].freeze,
      :numeric  => [:integer, :float, :decimal].freeze,
      :temporal => [:date, :datetime, :time, :timestamp].freeze,
      :boolean  => [:boolean].freeze
    }.freeze

    #
    # This lists all official/supported aliases for Axis attribute types. The
    # keys are the aliases and the values are the official Axis attribute types
    # that the alias maps to.
    #
    # In order to make this easy to use, there is some redundancy in this hash.
    # Specifically, the official Axis attribute types have alias entrys (they
    # just map back to themselves) as do the "first-class" aliases that are
    # already listed in the value lists in the TYPES constant above. This is so
    # that you can quickly map any type (alias, "first-class" alias, or official
    # type) to the official attribute type.
    #
    ALIASES = {
      :string    => :string,   # official type
      :binary    => :binary,   # official type
      :numeric   => :numeric,  # official type
      :temporal  => :temporal, # official type
      :boolean   => :boolean,  # official type
      :text      => :string,   # first-class alias
      :char      => :string,   # alias
      :clob      => :string,   # alias
      :blob      => :binary,   # alias
      :integer   => :numeric,  # first-class alias
      :float     => :numeric,  # first-class alias
      :decimal   => :numeric,  # first-class alias
      :number    => :numeric,  # alias
      :int       => :numeric,  # alias
      :double    => :numeric,  # alias
      :date      => :temporal, # first-class alias
      :datetime  => :temporal, # first-class alias
      :time      => :temporal, # first-class alias
      :timestamp => :temporal, # first-class alias
      :bool      => :boolean   # alias
    }.freeze

    #
    # Create a minimal Attribute instance that isn't yet displayable, sortable,
    # or searchable.
    #
    def initialize(model, name, fields, type = nil)
      @model  = Axis.validate_model(model)
      @name   = self.class.validate_name(name)
      @fields = Axis.validate_columns(fields, @model)
      if @fields.length == 1 and @fields.first == @name
        @literal = true
        @type    = self.class.validate_type(@model.columns_hash[@name].type)
        if type
          type = self.class.validate_type(type)
          raise ArgumentError, "type provided for literal attribute (#{type.class}:#{type}) " +
            "doesn't match column's type: #{@type}" unless ALIASES[type] == ALIASES[@type]
        end
      else
        @literal = false
        @type    = self.class.validate_type(type)
      end
      @filter      = nil # when searchable, an Axis::Attribute::Filter instance
      @caption     = nil # when displayable, string (attribute's display name)
      @display     = nil # when displayable, block of code (or still nil)
      @sort        = nil # when sortable, array of Sort instances
      @searchable  = false
      @displayable = false
      @sortable    = false
    end

    #
    # Convert this attribute into a searchable one (or re-configure its search
    # settings).
    #
    def searchable(options = {}, &block)
      raise ArgumentError, "invalid type for options hash: #{options.class}" unless options.is_a?(Hash)
      filter      = options.delete(:filter) || :default
      @filter     = Axis::Attribute::Filter.new(filter, @type, @model, options, &block)
      @searchable = true
    end

    #
    # Convert this attribute into a displayable one (or re-configure its display
    # settings).
    #
    def displayable(caption = nil, &block)
      @caption     = caption ? self.class.validate_caption(caption) : @name.titleize.freeze
      @display     = block
      @displayable = true
    end

    #
    # Convert this attribute into a sortable one (or re-configure its sorting
    # settings).
    #
    def sortable(*sort)
      raise "cannot make an Axis::Attribute sortable until its first displayable" unless @displayable
      @sort     = self.class.validate_sort(sort, @model, @fields)
      @sortable = true
    end

    attr_reader :model   # a class inheriting from ActiveRecord::Base
    attr_reader :name    # frozen string
    attr_reader :fields  # frozen array of frozen strings
    attr_reader :type    # symbol
    attr_reader :filter  # Filter instance
    attr_reader :caption # frozen string
    attr_reader :sort    # array of Sort instances

    def string?      ; ALIASES[@type] == :string   ; end
    def binary?      ; ALIASES[@type] == :binary   ; end
    def numeric?     ; ALIASES[@type] == :numeric  ; end
    def temporal?    ; ALIASES[@type] == :temporal ; end
    def boolean?     ; ALIASES[@type] == :boolean  ; end
    def literal?     ;  @literal     ; end
    def logical?     ; !@literal     ; end
    def searchable?  ;  @searchable  ; end
    def displayable? ;  @displayable ; end
    def sortable?    ;  @sortable    ; end

    ############################################################################
    class << self
    ############################################################################

      #
      # Allow access to the official attribute registry. This provides two
      # access methods, a one and a two parameter version. This allows you to
      # do the following to attempt to get access to an attribute instance
      # respectively:
      #
      #   Axis::Attribute[MyModel][:last_name]
      #   Axis::Attribute[MyModel, :last_name]
      #
      # ====== 1. One Parameter Version ======
      #
      # The first version, the one-parameter version, tries to return the hash
      # that contains all attributes registered under the specified model. If
      # parameter you provide as a model either isn't a valid model class or is
      # valid but doesn't yet have any attributes registered for it, then an
      # empty hash is returned.
      #
      # Either way you are always guaranteed to always have a hash returned.
      # You are ALSO guaranteed that the returned hash is a duplicate of the
      # underlying registration hash. The point being that you CANNOT use it to
      # register a new attribute. In other words, the following HAS NO EFFECT:
      #
      #   Axis::Attribute[MyModel][:last_name] = my_attribute # DOESN'T WORK!
      #
      # This is deliberate as the bracket operators give you read-only access to
      # the registration collection.
      #
      # Review: The one parameter version ALWAYS returns a hash, even if the
      #         parameter is invalid or otherwise has no attributes registered.
      #
      # ====== 2. Two Parameter Version ======
      #
      # The second version, the two-parameter version, takes both a model and
      # a name in order to immediately do a full lookup for the attribute with
      # the given name, registered to the provided model. This version will
      # either return an attribute instance if the lookup is successful or will
      # return nil.
      #
      # So, the differentiator here is that this version MAY RETURN NIL. If the
      # parameters are invalid or, if valid but there isn't an attribute yet
      # registered to the provided model with the provided name, then nil is
      # returned (no exceptions are raised). Otherwise you'll get a reference to
      # the registered attribute.
      #
      # Review: This may return nil. Otherwise it returns an Axis::Attribute
      #         instance.
      #
      def [](model, name = nil)
        result = attributes[model]
        if name
          # model plus name lookup either gives you a reference to the
          # associated attribute or nil...
          result ? result[name] : nil
        else
          # model-only variation never gives you original hash, but always gives
          # you *a* hash...
          result ? result.dup : {}
        end
      end

      #
      # Finds or creates a new attribute using the same method signature as the
      # model helper #axis_search_on (with an additional leading parameter for
      # the model class). If an existing attribute is found, it is updated
      # according to the requested search settings. The new (or existing)
      # instance is returned and a reference saved in the global collection.
      #
      def searchable(model, *args, &block)
        result, options = load(model, args)
        options = args.extract_options!
        type    = options.delete(:type)
        name    = options.delete(:name)
        find_or_create(model, name, args, type).searchable(options, &block)
      end

      #
      # Finds or creates a new attribute using the same method signature as the
      # model helper #axis_display_on (with an additional leading parameter for
      # the model class). If an existing attribute is found, it is updated
      # according to the requested display settings. The new (or existing)
      # instance is returned and a reference saved in the global collection.
      #
      def displayable(model, *args, &block)
        options = args.extract_options!
        type    = options.delete(:type)
        name    = options.delete(:name)
        caption = options.delete(:caption)
        find_or_create(model, name, args, type).displayable(caption, &block)
      end

      #
      # Finds or creates a new attribute using the same method signature as the
      # model helper #axis_sort_on (with an additional leading parameter for
      # the model class). If an existing attribute is found, it is updated
      # according to the requested sort settings. The new (or existing) instance
      # is returned and a reference saved in the global collection.
      #
      def sortable(model, *args, &block)
        options = args.extract_options!
        type    = options.delete(:type)
        name    = options.delete(:name)
        caption = options.delete(:caption)
        sort    = options.delete(:sort)
        result  = find_or_create(model, name, args, type)
        if caption
          result.displayable(caption, &block)
        end
        result.sortable(sort || true)
      end

      #
      # Finds or creates (and registers if creating) an attribute with the
      # provided characteristics. The attribute will be basic if created (not
      # yet displayable, sortable, or searchable). If an attribute for the
      # specified model and name is already registered then it will be returned
      # *after* it is verified that the type (if provided) and fields match the
      # existing attribute.
      #
      def load(model, args)
        name   = validate_name(name) # mainly to normalize for lookup
        result = self[model, name]
        if result
          fields = Axis.validate_columns(fields)
          type   = validate_type(type) if type
          raise ArgumentError, "provided fields list (#{fields.join(', ')}) doesn't match " +
            "existing attribute's list: #{result.fields.join(', ')}" unless fields == result.fields
          raise ArgumentError, "provided attribute type (#{type}) doesn't match " +
            "existing attribute's type: #{result.type}" unless !type or type == result.type
        else
          result                  = new(model, name, fields, type)
          attributes[model]     ||= {}
          attributes[model][name] = result
        end
        result
        
      end

      def find_or_create(model, name, fields, type = nil)
      end

      def validate_name(name)
        result = name.is_a?(Symbol) ? name.to_s : name
        raise ArgumentError, "invalid type for name: #{name.class}" unless result.is_a?(String)
        raise ArgumentError, "invalid name: #{result}"              unless result =~ /\A[a-z0-9_-]+\z/i
        result.gsub(/-/, "_").freeze
      end

      def validate_type(type)
        result = type.is_a?(String) ? type.intern : type
        raise ArgumentError, "invalid type for type: #{type.class}" unless result.is_a?(Symbol)
        raise ArgumentError, "invalid type: #{result}"              unless ALIASES[result]
        if TYPE[ALIASES[result]].include?(result)
          result # retain first-class aliases un-normalized
        else
          ALIASES[result]
        end
      end

      def validate_caption(caption)
        result = caption.is_a?(Symbol) ? caption.to_s : caption
        raise ArgumentError, "invalid type for caption: #{caption.class}" unless result.is_a?(String)
        raise ArgumentError, "invalid caption: (blank)"                   if result.strip.empty?
        result.strip.freeze
      end

      def validate_sort(sort, model, fields = nil)
        result = case sort
        when Hash  then validate_sort_hash(sort, model)
        when Array then validate_sort_array(sort, model)
        else
          raise ArgumentError, "invalid type for fields: #{fields.class}" unless fields.is_a?(Array)
          fields.map { |f| Axis::Attribute::Sort.new(sort, f, model) }
        end.flatten
        raise ArgumentError, "no sort fields specified" if result.empty?
        result.uniq.freeze
      end

      ##########################################################################
      private
      ##########################################################################

      #
      # Access to the attribute registration collection.
      #
      def attributes
        @attributes ||= {}
      end

      #
      # Helper used to process "sort" options for the provided model that are in
      # "hash" format. Called by the public #validate_sort method above and the
      # #validate_sort_array recursive helper below to help process "sort"
      # options (see #validate_sort for more info).
      #
      def validate_sort_hash(sort, model)
        sort.map do |column, type|
          Axis::Attribute::Sort.new(type, column, model)
        end
      end

      #
      # Recursively validate an "normalize" (convert into Axis:Attribute::Sort
      # instances) an array of "sort" options for the provided model. Called by
      # the public #validate_sort method (and itself of course) to help process
      # "sort" options (see #validate_sort for more info).
      #
      def validate_sort_array(sort, model)
        #
        # First try to process any 2-element arrays that may be [column, type]
        # sorting definitions...
        #
        result = nil
        if sort.length == 2 and
          (sort.first.is_a?(String) or sort.first.is_a?(Symbol)) and
          (sort.last.is_a?(String)  or sort.last.is_a?(Symbol))
          begin
            result = Axis::Attribute::Sort.new(sort.last, sort.first, model)
          rescue ArgumentError
            result = nil
          end
        end
        return [result] if result
        #
        # Now just process the array as a list of sorting definitions...
        #
        result = sort.map do |entry|
          case entry
          when Hash  then validate_sort_hash(entry, model)
          when Array then validate_sort_array(entry, model)
          when Axis::Attribute::Sort
            # invalid if model doesn't match...
            raise ArgumentError, "Model in Axis::Attribute::Sort instance in sort options array doesn't match\n" +
              "our model:\n" +
              "  Sort Instance: <id=#{entry.id} type=#{entry.type} model=#{entry.model.name} column=#{entry.column}>\n" +
              "  Our Model:     #{model.name}" unless model == entry.model
            # ...otherwise just (re)use this instance since they're immutable
            entry 
          else
            # let the Sort class's initializer validate the column name
            Axis::Attribute::Sort.new(true, entry, model)
          end
        end
        raise ArgumentError, "no sort fields specified in array" if result.empty?
        result
      end

    ############################################################################
    end # class << self
    ############################################################################

  end # class Attribute
end   # module Axis
