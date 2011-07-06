# encoding: utf-8
require 'axis/validate'

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
  # data columns. Logical attributes include code that knows how to combine or
  # otherwise transform the data columns into a new, single data type in
  # addition to the metadata that all Axis attributes store.
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
    def initialize(model, name, columns, type = nil)
      @model  = Validate.model(model)
      @name   = self.class.validate_name(name).freeze
      @columns = Validate.columns(columns, @model).freeze
      @columns.each { |c| c.freeze }
      if @columns.length == 1 and @columns.first == @name
        @literal = true
        @type    = self.class.validate_type(@model.columns_hash[@name].type)
        if type
          type = self.class.validate_type(type)
          raise ArgumentError, "type provided for literal attribute (#{type.class}:#{type}) " +
            "doesn't match column's type: #{@type}" unless ALIASES[type] == ALIASES[@type]
        end
      else
        type   ||= @model.columns[@columns.first].type if @columns.length == 1
        @literal = false
        @type    = self.class.validate_type(type)
      end
      @filter      = nil # when searchable, an Axis::Attribute::Filter instance
      @caption     = nil # when displayable, string (attribute's display name)
      @renderer    = nil # when displayable, block of code (or still nil)
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
      @filter     = Axis::Attribute::Filter.create(filter, @model, @type, options, &block)
      @searchable = true
    end

    #
    # Convert this attribute into a displayable one (or re-configure its display
    # settings).
    #
    def displayable(caption = nil, &block)
      @caption     = caption ? self.class.validate_caption(caption).freeze : @name.titleize.freeze
      @renderer    = block
      @displayable = true
    end

    #
    # Convert this attribute into a sortable one (or re-configure its sorting
    # settings).
    #
    def sortable(*sort)
      raise "cannot make an Axis::Attribute sortable until its first displayable" unless @displayable
      sort      = sort.first unless sort.length > 1 # unwrap calls w/just one parameter out of array
      @sort     = self.class.validate_sort(sort, @model, @columns)
      @sortable = true
    end

    attr_reader :model   # a class inheriting from ActiveRecord::Base
    attr_reader :name    # frozen string
    attr_reader :columns # frozen array of frozen strings
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

    #
    # This is the attribute's "display" name which is just the #humanize-ed
    # version of it's name unless it is a searchable attribute with the :display
    # option set, in which case that name is used instead.
    #
    def display
      filter.try(:display) || name.humanize
    end

    #
    # This is the standard technique used to render an attribute to it's desired
    # output object. The caller, however, must provide the actual model instance
    # that has this attribute.
    #
    def render(record)
      raise ArgumentError, "record's class doesn't match attribute's model: #{record.class} != #{model}" unless record.class == model
      values = columns.map { |c| record.send(c) }
      return values.first if columns.length == 1 and !@renderer
      if @renderer
        @renderer.call(*values)
      else
        values.compact.join(" ")
      end
    end

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
        result = attributes[Normalize.model(model)]
        if name
          # model plus name lookup either gives you a reference to the
          # associated attribute or nil...
          result ? result[normalize_name(name)] : nil
        else
          # model-only variation never gives you original hash, but always gives
          # you *a* hash...
          result ? result.dup : {}
        end
      end

      #
      # This takes a model and a list of arguments and returns two values (in a
      # two-element array), a registered attribute instance (first) and an
      # options hash (last).
      #
      # This expects to process argument in the same form as those passed to the
      # model macro helper methods: #axis_search_on, #axis_display_on,
      # #axis_sort_on, and #axis_on. The arguments accepted by these methods are
      # passed through to the Attribute class methods #searchable, #displayable,
      # #sortable, and #create respectively. These four then immediately use
      # method to actually process the arguments originally provided in the
      # model.
      #
      # If the arguments are invalid then an ArgumentError is raised.
      #
      # The method expects there to optionally be a hash as the last argument in
      # the list of parameters. This is the standard, optional "options" hash
      # that is common in most APIs. This is what gets returned as the second
      # entry in the returned, two-element array. If the last argument isn't a
      # hash then an empty hash is created and returned. So, either way, an
      # options hash gets returned to the caller.
      #
      # However, if there *is* an options hash passed to this method, some of
      # the entries, if they exist, will be processed and removed before the
      # options hash is returned. Namely, the :name and :type entries.
      #
      # All arguments besides the optional options hash should reference the
      # name of a column in the provided model (or be a nested array of such
      # references). There must be at least one such argument besides the
      # options hash. However, if there is exactly on such argument, instead
      # of referencing a column name, it may optionally reference the name of
      # an existing, registered attribute.
      #
      # Either way, these names may be symbols or strings and will be used to
      # either find an existing, registered attribute that references the same
      # list of columns (in the same order) or create a new one. If a new one
      # is created it will be in the most basic state, meaning it won't yet be
      # displayable, sortable, or searchable. Also, it will be registered once
      # returned. It an existing attribute is returned, it could be in any
      # state.
      #
      def load(model, *args)
        model   = Validate.model(model)
        options = args.extract_options!
        columns = args.flatten
        name    = validate_name(options.delete(:name)) if options.has_key?(:name)
        type    = validate_type(options.delete(:type)) if options.has_key?(:type)
        result  = [nil, options]

        #
        # Handle special case where a single column name provided that refers
        # to the name of a pre-existing logical attribute...
        #
        if columns.length == 1 and !name
          name = validate_name(columns.first)
          tmp  = self[model, name]
          if tmp and tmp.logical?
            columns = tmp.columns
          end
        end

        #
        # Validate list of columns and lookup attribute using name
        #
        raise ArgumentError, "no attribute name or list of column names provided" if columns.empty?
        raise ArgumentError, "no :name option provided; required for logical attributes (having several columns)" unless name
        columns   = Validate.columns(columns, model)
        result[0] = self[model, name]

        #
        # If we found an existing attribute, validate that the :name and :type
        # options that were provided (if any) match. Otherwise create a new
        # attribute and register it.
        #
        if result[0]
          raise ArgumentError, "provided columns list (#{columns.join(', ')}) doesn't match " +
            "existing attribute's list: #{result[0].columns.join(', ')}" unless columns == result[0].columns
          raise ArgumentError, "provided attribute type (#{type}) doesn't match " +
            "existing attribute's type: #{result[0].type}" if type and type != result[0].type
        else
          result[0]               = new(model, name, columns, type)
          attributes[model]     ||= {}
          attributes[model][name] = result[0]
        end
        result
      end

      #
      # Finds or creates a new attribute using the same method signature as the
      # model helper #axis_search_on (with an additional leading parameter for
      # the model class). If an existing attribute is found, it is updated
      # according to the requested search settings. The new (or existing)
      # instance is returned and a reference saved in the global collection.
      #
      def searchable(model, *args, &block)
        result, options = load(model, *args)
        result.searchable(options, &block)
      end

      #
      # Finds or creates a new attribute using the same method signature as the
      # model helper #axis_display_on (with an additional leading parameter for
      # the model class). If an existing attribute is found, it is updated
      # according to the requested display settings. The new (or existing)
      # instance is returned and a reference saved in the global collection.
      #
      def displayable(model, *args, &block)
        result, options = load(model, *args)
        result.displayable(options[:caption], &block)
      end

      #
      # Finds or creates a new attribute using the same method signature as the
      # model helper #axis_sort_on (with an additional leading parameter for
      # the model class). If an existing attribute is found, it is updated
      # according to the requested sort settings. The new (or existing) instance
      # is returned and a reference saved in the global collection.
      #
      def sortable(model, *args, &block)
        result, options = load(model, *args)
        if !result.displayable? or options[:caption] or block
          result.displayable(options[:caption], &block)
        end
        result.sortable(options[:sort] || true)
      end

      #
      # Finds or creates a new attribute using the same method signature as the
      # model helper #axis_on (with an additional leading parameter for the
      # model class). If an existing attribute is found, it is updated according
      # to the requested settings (for searching, display or sorting) included
      # in the argument list (and options hash). The new (or existing) instance
      # is returned and a reference saved in the global collection.
      #
      def create(model, *args, &block)
        result, options = load(model, *args)
        if options[:caption]
          result.displayable(options.delete(:caption), &block)
          block = nil
        end
        result.sortable(options.delete(:sort)) if options.has_key?(:sort)
        (options.empty? and block.nil?) ? result : result.searchable(options, &block)
      end

      #
      # Convert any acceptable forms for "name" parameters into a standard form,
      # namely a string. Returns the parameter as-is if it is already a string
      # or if it is in an invalid form. This doesn't raise errors.
      #
      def normalize_name(name)
        result = name.is_a?(Symbol) ? name.to_s             : name
        result.is_a?(String)        ? result.gsub(/-/, "_") : name
      end

      #
      # Normalize and validate any acceptable forms for "name" parameters. If
      # the parameter is not in a valid form that represents an attribute name
      # then an ArgumentError is raised. Otherwise, the normalized form of the
      # parameter is returned (a string).
      #
      def validate_name(name)
        result = normalize_name(name)
        raise ArgumentError, "invalid type for name: #{name.class}" unless result.is_a?(String)
        raise ArgumentError, "invalid name: #{result}"              unless result =~ /\A[a-z0-9_-]+\z/i
        result
      end

      #
      # Convert any acceptable forms for "type" parameters into a standard form,
      # namely a symbol. Returns the parameter as-is if it is already a symbol
      # or if it is in an invalid form. This doesn't raise errors.
      #
      def normalize_type(type)
        result = type.is_a?(String) ? type.intern : type
        if result.is_a?(Symbol)
          if ALIASES[result] and TYPES[ALIASES[result]].include?(result)
            result # retain first-class aliases un-normalized
          elsif ALIASES[result]
            ALIASES[result] # un-alias valid aliases
          else
            type # symbol, but not a valid type: return as-is
          end
        else
          type # not even a symbol, return parameter as-is
        end
      end

      #
      # Normalize and validate any acceptable forms for "type" parameters. If
      # the parameter is not in a valid form that represents an attribute's type
      # then an ArgumentError is raised. Otherwise, the normalized form of the
      # parameter is returned (a symbol).
      #
      def validate_type(type)
        result = normalize_type(type)
        raise ArgumentError, "invalid type for type: #{type.class}" unless result.is_a?(Symbol)
        raise ArgumentError, "invalid type: #{result}"              unless ALIASES[result]
        result
      end

      #
      # Convert any acceptable forms for "caption" parameters into a standard
      # form, namely a string. Returns the parameter as-is if it is already a
      # string or if it is in an invalid form. This doesn't raise errors.
      #
      def normalize_caption(caption)
        result = caption.is_a?(Symbol) ? caption.to_s  : caption
        result.is_a?(String)           ? result.strip  : caption
      end

      #
      # Normalize and validate any acceptable forms for "caption" parameters. If
      # the parameter is not in a valid form that represents an attribute's
      # caption then an ArgumentError is raised. Otherwise, the normalized form
      # of the parameter is returned (a string).
      #
      def validate_caption(caption)
        result = normalize_caption(caption)
        raise ArgumentError, "invalid type for caption: #{caption.class}" unless result.is_a?(String)
        raise ArgumentError, "invalid caption: (blank)"                   if     result.empty?
        result
      end

      #
      # Normalize and validate any acceptable forms for "sort" parameters. If
      # the parameter (or any parts thereof) is not in a valid form that
      # represents the sorting configuration for an attribute then an
      # ArgumentError is raised. Otherwise, the normalized form of the
      # parameter is returned (an array of Axis::Attribute::Sort instances).
      #
      # NOTE: Notice the lack of an associated #normalize_sort method. This
      #       method includes normalization as valid "sort" parameters are
      #       too complex to justify the code-duplication this would require.
      #
      def validate_sort(sort, model, columns = nil)
        result = case sort
        when Hash  then validate_sort_hash(sort, model)
        when Array then validate_sort_array(sort, model)
        else
          raise ArgumentError, "invalid type for columns: #{columns.class}" unless columns.is_a?(Array)
          columns.map { |f| Axis::Attribute::Sort.new(sort, f, model) }
        end.flatten
        raise ArgumentError, "no sort columns specified" if result.empty?
        result.uniq
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
      # Recursively validate and "normalize" (convert into Axis:Attribute::Sort
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
        raise ArgumentError, "no sort columns specified in array" if result.empty?
        result
      end

    ############################################################################
    end # class << self
    ############################################################################

  end # class  Attribute
end   # module Axis
