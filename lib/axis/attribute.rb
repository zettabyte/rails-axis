# vim: fileencoding=utf-8:

require 'axis/attribute/filter'
require 'axis/attribute/sort'

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

    class << self

      def [](model, name = nil)
        result = attributes[model]
        if name
          # model plus name lookup either gives you a reference to the
          # associated attribute or nil...
          result[name]
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
      # according to the requested search settings.
      #
      def searchable(model, *args, &block)
        raise ArgumentError, "invalid model type: #{model.class}" unless model.is_a?(Class)
        raise ArgumentError, "invalid model: #{model.name}" unless model.ancestors.include?(ActiveRecord::Base)
        options = args.extract_options!
        attrs   = args.flatten.map do |attr|
          attr  = attr.is_a?(Symbol) : attr.to_s : attr
          raise ArgumentError, "invalid attribute type: #{attr.class}" unless attr.is_a?(String)
          raise ArgumentError, "invalid attribute: #{attr}" unless model.column_names.include?(attr)
          attr
        end
        raise ArgumentError, "no attributes provided" if attrs.empty?
        raise ArgumentError, "some attributes specified multiple times" if (attrs.uniq.length < attrs.length).empty?

        type = options.delete(:type)
        name = options.delete(:name)
        options[:filter]
        options[:not]
        options[:null]
        options[:blank]
        options[:empty]
        options[:multi]
        options[:false]
        options[:values]
        new(type, model, name, "Unset Caption", attrs, nil, nil, block)

      end

      def for(model, name)
        # Validate name's type so if callers pass nil for it, it doesn't screw
        # up our call to #[]; we'll be sure to get an Attribute or nil...
        raise ArgumentError, "name must be a string or symbol, not a: #{name.class}" unless
          name.is_a?(String) or name.is_a?(Symbol)
        result = self[model, name]
        result ? result : new(__type__, model, name, ...)
      end

      private
      def attributes
        @attributes ||= {}
      end

    end

    #
    # Create an Axis::Attribute instance of the specified type, associated with
    # the specified model class, having the provided name and caption. The
    # attribute will be associated with the specified fields (this being an
    # array of column names belonging to the associated model class). Also, the
    # attribute will allow sorting (if not false or nil) using the provided
    # sorting options. Finally, the attribute will transform the values of all
    # associated fields into a single data object using the provided display
    # block and will filter records using user-provided input using the provided
    # filter block.
    #
    # The default constructor has a rigid method signature because it isn't
    # designed to be used directly by client code (though it is available).
    #
    def initialize(type, model, name, caption, fields, sorting, display, filter)
      #
      # Validate, normalize, and otherwise process our various parameters into
      # our instance variables. The validation routines are written to expect
      # this call order and they'll raise exceptions if their arguments (or the
      # state of the object) is invalid.
      #
      @type    = validate_type(type)
      @model   = validate_model(model)
      @name    = validate_name(name)
      @caption = validate_caption(caption)
      @fields  = validate_fields(fields)
      @sort    = validate_sort(sorting)
      @display = validate_display(display)
      @filter  = validate_filter(filter)
      @literal = true
    end

    def string?   ; ALIASES[@type] == :string   ; end
    def binary?   ; ALIASES[@type] == :binary   ; end
    def numeric?  ; ALIASES[@type] == :numeric  ; end
    def temporal? ; ALIASES[@type] == :temporal ; end
    def boolean?  ; ALIASES[@type] == :boolean  ; end

    def literal? ;  @literal ; end
    def logical? ; !@literal ; end

    def display? ; !!@display ; end
    def sort?    ; !!@sort    ; end
    def filter?  ; !!@filter  ; end

    attr_reader :type
    attr_reader :name
    attr_reader :caption
    attr_reader :fields

    ############################################################################
    private
    ############################################################################

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

    def validate_model(model)
      raise ArgumentError, "invalid type for model: #{model.class}" unless model.is_a?(Class)
      raise ArgumentError, "invalid model: #{model.name}"           unless model.ancestors.include?(ActiveRecord::Base)
      model
    end

    def validate_name(name)
      result = name.is_a?(String) ? name.intern : name
      raise ArgumentError, "invalid type for name: #{name.class}" unless result.is_a?(Symbol)
      raise ArgumentError, "invalid name: #{result}"              unless result.to_s =~ /\A[a-z0-9_-]+\z/i
      result
    end

    def validate_caption(caption)
      result = caption.is_a?(Symbol) ? caption.to_s : caption
      raise ArgumentError, "invalid type for caption: #{caption.class}" unless result.is_a?(String)
      raise ArgumentError, "invalid caption: (blank)"                   if result.strip.empty?
      result.strip.freeze
    end

    def validate_fields(fields)
      result = [fields].flatten.map do |field|
        tmp = field.is_a?(String) ? field.intern : field
        raise ArgumentError, "invalid type for field: #{field.class} (#{field})" unless tmp.is_a?(Symbol)
        raise ArgumentError, "invalid field: #{tmp}" unless tmp.to_s != "" @model.column_names.include?(tmp.to_s)
      end.uniq.freeze
      raise ArgumentError, "no fields provided" if result.empty?
      result
    end

    def validate_sort(sort)
      result = case sort
      when Hash  then sort_options_hash(sort)
      when Array then sort_options_array(sort)
      else
        if sort
          @fields.map { |f| Axis::Attribute::Sort.new(sort, f, @model) }
        else
          nil # sorting turned off
        end
      end
      raise ArgumentError, "no sort fields specified" if result and result.empty?
      result ? result.flatten.uniq.freeze : nil
    end

    def validate_display(display)
      return display if [nil, true].include?(display)
      raise ArgumentError, "invalid type for display: #{display.class}" unless display.is_a?(Proc)
      display
    end

    def validate_filter(filter)
      return filter if [nil, true].include?(filter)
      raise ArgumentError, "invalid type for filter: #{filter.class}" unless filter.is_a?(Proc)
      filter
    end

    #
    # Used to recursively process a sort options array. The @model must already
    # be set. Returns an array of Axis::Attribute::Sort instances.
    #
    def sort_options_array(sort)
      #
      # First try to process any 2-element arrays that may be [column, type]
      # sorting definitions...
      #
      result = nil
      if sort.length == 2 and
        (sort.first.is_a?(String) or sort.first.is_a?(Symbol)) and
        (sort.last.is_a?(String)  or sort.last.is_a?(Symbol))
        begin
          result = Axis::Attribute::Sort.new(sort.last, sort.first, @model)
        rescue ArgumentError
          reuslt = nil
        end
      end
      return [result] if result

      #
      # Now just process the array as a list of sorting definitions...
      #
      result = sort.map do |entry|
        case entry
        when Hash  then sort_options_hash(entry)
        when Array then sort_options_array(entry)
        when Axis::Attribute::Sort
          # invalid if model doesn't match...
          raise ArgumentError, "Model in Axis::Attribute::Sort instance in sort options array doesn't match\n" +
            "our model:\n" +
            "  Sort Instance: <id=#{entry.id} type=#{model.type} model=#{entry.model.name} column=#{entry.column}>\n" +
            "  Our Model:     #{@model.name}" unless @model == entry.model
          # ...otherwise just (re)use this instance since they're immutable
          entry 
        else
          # let the Sort class's initializer validate the column name
          Axis::Attribute::Sort.new(true, entry, @model)
        end
      end
      raise ArgumentError, "no sort fields specified in array" if result.empty?
      result
    end

    #
    # Used to break out logic used to process sort options contained within a
    # hash. Called by #validate_sort and #sort_options_array.
    #
    def sort_options_hash(sort)
      sort.map do |column, type|
        Axis::Attribute::Sort.new(type, column, @model)
      end
    end

  end # class Attribute
end   # module Axis
