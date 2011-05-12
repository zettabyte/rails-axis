# vim: fileencoding=utf-8:
module Axis
  module Model

    #
    # Add our class methods too.
    #
    def self.included(base)
      base.send(:extend, ClassMethods)
    end

    module ClassMethods

      #
      # This defines the search or filtering behavior of a literal or logical
      # column as defined by the parameters.
      #
      # If the column has already been defined by another #axis_search_on,
      # #axis_sort_on, or #axis_column_on call then the column's definition will
      # be updated to have the searching behavior defined by this method call.
      #
      # To define a literal column, just list the column/attribute's name (as a
      # string or symbol) as the first and only argument beside the options
      # hash (last argument). Also, you must *not* provide either a :name or
      # :type option, or provide a block, in order for the column to remain a
      # _literal_ column.
      #
      # To define a logical column, provide all the involved column names
      # (strings or symbols) directly in the parameter list or grouped in one or
      # more arrays. Whether the logical column aggregates several or just one
      # literal column, you must give the _logical_ column a :name either way.
      # The name must be unique amongst all literal column names and existing
      # logical columns. If the :name matches an existing logical column and the
      # list of literal source columns is the same then this will just update
      # the existing logical column.
      #
      # Additionally, if creating a logical column that wraps multiple literal
      # columns, then you must provide a :type option AND provide a block to
      # the call.
      #
      # Example: literal column
      #   axis_search_on :first_name
      #
      # Example: logical columns
      #   # Logical because it tweaks actual search logic w/code block:
      #   axis_search_on :registered_at do |value|
      #     self.active.where(:yourmom => "huge", :and_has_no => values)
      #   end
      #   # Logical because it renames (is an alias for) a literal column:
      #   axis_search_on :full_name, :name => :full, :filter => :pattern
      #   # Clearly a logical column as it combines several literal columns;
      #   # it also provides a name and type option along with a code block
      #   # that performs the actual filtering using the user-provided values,
      #   # all of which must be done when combining several columns.
      #   axis_search_on :first_name, :middle_name, :last_name, :name => :full,
      #                  :type => :string, :filter => :pattern do |pattern|
      #     self.where("first_name LIKE :pattern OR middle_name LIKE :pattern" +
      #                " OR last_name LIKE :pattern", :pattern => pattern)
      #   end
      #   # Ditto.
      #   axis_search_on %w{ proceeds taxes }, :name => "net",
      #                  :type => :decimal, :filter => :range do |low, high|
      #     self.where("(proceeds - taxes) BETWEEN :low AND :high",
      #                :low => low, :high => high)
      #   end
      #
      # If defining a logical column that uses several source columns, you must
      # define the column's data :type. The type must be one of the ActiveRecord
      # column types: :string, :text, :integer, :float, :decimal, etc.
      #
      # One of the primary and most useful options is the :filter type option.
      # This is used by axis view helpers to determine what kind of filter UI to
      # draw and filtering options to provide on the column. If you don't
      # specify a :filter option, it is the same as if you specified:
      #
      #   :filter => :default
      #
      # The value of :filter determines what other options you may provide. For
      # example, the :set value makes the method also check if there is an
      # option named :multi in case you want a "Multi-Set".
      #
      # Example: Multi-Set Column on a :string Field (Literal Column)
      #   axis_search_on :category, :filter => :set, :multi => true,
      #                  :values => %w{ suspense sci-fi fantasy mystery ... }
      #
      # So, the set of recognized options depends on the value of :filter. It
      # also depends on the underlying data type (either the literal column's
      # data type or the logical column's type as defined by :type). For this
      # reason, the list of available options will first be listed and briefly
      # described for completeness. Then there will be seperate lists and extra
      # descriptions organized by various combinations of data type and :filter
      # values.
      #
      # == Options ==
      #
      #   :name   | Logical column's name
      #   :type   | Logical column's data-type
      #   :filter | One of: :default, :set, :null, :boolean, :range or :pattern
      #   :not    | Boolean: include _negation_ checkbox with filter
      #   :null   | Boolean: include "is unset" option in lists, checks for NULL
      #   :blank  | Boolean: include "is blank" option, matches NULL or empty
      #   :empty  | Boolean: include "is empty" option, matches empty strings
      #   :multi  | Boolean: makes :set filters multisets
      #   :false  | Boolean: used only when :filter is :boolean (see docs below)
      #   :values | Array of values (types depend on :type) for :set filters
      #
      # === Filter Type: :default ===
      #
      # If :filter is :default (or isn't specified) then the default "equality"
      # filter is used to search on the column. For most data types, this
      # allows the user to enter a value in a text input box. They may also have
      # a listbox from which they can instead select their value or additionally
      # select a comparison type.
      #
      # ==== String Types: :text, :string ====
      #
      # You can provide the :not, :null, :blank, and :empty options as desired.
      # After the column's name (and optional "not" checkbox) a listbox is
      # displayed with the following values in the following order and with the
      # first option pre-selected (no blank entry):
      #
      #   Matches     | does string equality comparison
      #   Starts With | uses: column LIKE 'val%'
      #   Ends With   | uses: column LIKE '%val'
      #   Contains    | uses: column LIKE '%val%'
      #   [Is Blank]  | if :blank is true; ignores value; matches NULL and ""
      #   [Is Unset]  | if :null  is true; ignores value; matches NULL (IS NULL)
      #   [Is Empty]  | if :empty is true; ignores value; matches ""
      #
      # A textbox input get a search value from the user (which may be ignored
      # in some instances, such is if "Is Blank" is selected). This value is
      # used to compare against the value in the column.
      #
      # In no text in entered in the textbox and none of the optional "Is ..."
      # options are selected in the listbox then this filter is ignored.
      #
      # ==== Numeric Types: :integer, :float, :decimal
      #
      # For numeric types with a :default value for :filter, you may provide the
      # same set of options as with string types except for :blank and :empty.
      # The options displayed in the listbox and associated comparisons to the
      # user-entered value are:
      #
      #   =       | does an exact numeric equality comparison
      #   <       | less-than comparison
      #   >       | greater-than comparison
      #   <=      | less-than or equal-to comparison
      #   >=      | greater-than or equal-to comparison
      #   [Unset] | if :null is true; ignores value; matches NULL (IS NULL)
      #
      # If nothing is entered in the textbox and the "Unset" options isn't
      # selected in the listbox then this filter is ignored.
      #
      # ==== Temporal Types: :date, :time, :datetiem, :timestamp ====
      #
      # For temporal types with a :default value for :filter, these work just
      # like the numeric types above except the following options are displayed
      # in the listbox:
      #
      #   Equal To     | does an exact equality comparison
      #   Before       | less-than comparison (<)
      #   After        | greater-than comparison (>)
      #   Before or On | less-than or equal-to comparison (<=)
      #   After or On  | greater-than or equal-to comparison (>=)
      #   [Unset]      | if :null is true; ignores value; matches NULL (IS NULL)
      #
      # If nothing is entered in the textbox and the "Unset" option isn't
      # selected in the listbox then this filter is ignored.
      #
      # ==== Boolean Type: :boolean ====
      #
      # For columns with a :filter value of :default, :boolean columns differ
      # from other types the most. There is no text input box, just a single
      # listbox. You can provide the :not and :null options to get a negation
      # (or "not") checkbox and an extra "Unset" option in the listbox
      # respectively. The listbox will have a "true" and "false" option below
      # a first/default blank entry. When the blank entry is selected, this
      # filter is ignored.
      #
      #   <blank> | disables the filter if selected
      #   True    | searches where this column is true
      #   False   | searches where this column is false
      #   [Unset] | searches where this column IS NULL
      #
      # === Filter Type: :set ===
      #
      # If the :filter is :set then a listbox is used to display one or more
      # values, provided by the :values option, that the user can select. Only
      # records where the column matches this selected value will be displayed.
      #
      # You can use this filter type for all column types except :boolean ones.
      # If used, the following options are also recognized: :not, :null, :blank,
      # :empty, :multi and :values. However, :blank and :empty are only
      # recognized if the :type is one of the string types.
      #
      # The :null, :blank, and :empty options add "Unset", "Blank", and "Empty"
      # values to the listbox is present.
      #
      # If :multi is true, then the listbox will support multi-selection and
      # a given record will match the filter if the column's value matches any
      # one of the selected criterion.
      #
      # === Filter Type: :null ===
      #
      # This filter type may be applied to all column types. You may also
      # provide the :not and :multi options when using this filter type. As
      # always, the :not option adds a negation "not" checkbox. If :multi
      # *IS NOT* provided then this filter type simply renders a single
      # checkbox that, if checked, matches if the column IS NOT NULL and if
      # unchecked matches if the column IS NULL. As such, this filter always
      # applies (checkboxes can only be in two states).
      #
      # To add a third state, you may provide the :multi option which will
      # instead render two radio buttons instead of a checkbox. One will be
      # labelled "Set" and the other "Unset". Now, if neither are selected
      # (the "third" state) the the filter isn't applied. Otherwise one or
      # the other conditions is checked.
      #
      # For string-type columns (:text and :string) you may also pass the
      # :blank or :empty options (but not both). If one of these is passed then
      # instead of checking for NULL/NOT NULL, it will check if "blank" or not
      # or is "empty" or not respectively. A string is "blank" if it is either
      # the empty string ("") or NULL. A string is "empty" if it is the empty
      # string (""). The checkbox or radio button labels are modified
      # accordingly.
      #
      # Note that providing the :not option to such a simple filter type doesn't
      # make much sense here but is supported.
      #
      # === Filter Type: :boolean ===
      #
      # This filter type is only available on :boolean type columns. This offers
      # two more variations for dealing with boolean columns than available with
      # the listbox provided by the :default filter type. This filter type
      # supports the :not option, yielding a negation "not" checkbox, doubling
      # the number of variations available.
      #
      # This is useful since in databases boolean comparisons can be more
      # complicated than true boolean comparisons. This is because boolean
      # columns may often be allowed to be NULL. Also, in many DBMS there is no
      # native boolean type: it is just emulated (in this case by ActiveRecord)
      # and there may be several possible back-end values in the column. Thus,
      # just because a value DOESN'T match your "false" value doesn't mean it's
      # true. The reverse is also true.
      #
      # So, the first option supported is :multi. Without it, a checkbox is used
      # while with it, two radio buttons are used. With the radio buttons, if
      # neither is selected then the filter is ignored (3rd state). Otherwise
      # if the radio button labelled "True" is checked, then only records with
      # the column having the explicit true value are returned. If the "False"
      # radio button is checked, only those with the explicit false value are
      # returned (no NULL or other values). This is important since if your true
      # value is the number 1 and a record erroneously has a value of 2, some
      # might still consider this true but selecting "True" won't pick up this
      # record (neither will "False"). However, if "True" is selected along with
      # the "not" checkbox then it _will_ be selected.
      #
      # If :multi isn't provided (or is false) then a checkbox is used. If
      # checked, true values are returned. If, however, the :false option _is_
      # provided and the checkbox is checked, all false values are returned.
      # This is the only filter type that uses the :false option.
      #
      # === Filter Type: :range ===
      #
      # This filter type is supported by all the temporal and numeric column
      # types. This renders two textboxes in which the user can enter literal
      # values of the underlying column type. An sql BETWEEN clause is then
      # used to get all records where the column's value is between the two
      # values provided.
      #
      # This filter type supports only the :not option. It is ignored unless
      # both textboxes are filled with a valid literal value of the underlying
      # column type.
      #
      # === Filter Type: :pattern ===
      #
      # This is a string-type specific filter type (:string and :text columns).
      # This provides a simple textbox that the user can enter search text into.
      # There are no :blank, :null, or :empty options on this one. Just the :not
      # option.
      #
      # This allows the user to include the special characters "*" (star), "%"
      # (percent), and "_" (underscore) into their search string. The stars are
      # converted to percents. Otherwise, the search string is basically passed
      # in as is to an sql LIKE clause. This allows the user to have more power
      # doing text search patterns. Note that the user can search for literal
      # versions of each of the special characters by doubling them.
      #
      def axis_search_on(*args, &block)
        options = args.extract_options!
        columns = args.flatten.map { |c| c.to_s.blank? ? nil : c.to_s }.compact.uniq
        #raise ArgumentError, "you must provide one or more literal columns" if columns.empty?
        #name = options[:name]
        #type = options[:type]
        #if columns.length > 1 or name or type or block_given?
        #  # create logical column
        #  raise ArgumentError, "" unless name
        #  raise ArgumentError, "" unless type
        #else
        #  # create wrapper around literal column
        #  Attribute.new(self, x)
        #end
      end

      #
      # Passing a block or the :name or :scope options causes all listed fields
      # to be grouped together to make one "Search" entry.
      #
      # If no :name is specified, the "humanized" (where each word is also then
      # capitalized) form of the the field name is used to create the "Search"
      # entry.
      #
      # Only one search entry may exist per name: the name is the unique
      # identifyer AND is what get displayed in the search listbox to the end
      # user.
      #
      # Otherwise, a field may have several "Searches" created that search over
      # it.
      #
      # You may either provide a block or the :scope option but not both.
      #
      # If multiple fields are to be integrated into a single search, you MUST
      # provide either a :scope or a block that can take the search values and
      # scope the records down. You must likewise define the search data type:
      #
      # Supported Search Data Types:
      # ----------------------------
      # :primary_key
      # :reference
      # :integer
      # :float
      # :decimal
      # :boolean
      # :string
      # :text
      # :date
      # :time
      # :datetime
      # :timestamp
      #
      # Essentially, these are the supported rails "column" types. The column
      # type, if the search type isn't specified, is used to determine the
      # search type. Several of the above search types are, for the sake of
      # searching, considered aliases and effectively behave the same. The type
      # of the search determines what the form looks like for the search line
      # item: what kind of form inputs, etc:
      #
      # :primary_key => single text field
      # :reference   => if regular foreign key reference: single text field
      #                 if polymorphic: two text fields (id and type)
      # :integer     => drop-down w/ "=", "!=", "<", "<=", ">", ">="
      #
      # If its sortable, it should be displayed
      # 
      def axis_sort_on(*args)
      end

      #
      # Just add metadata to this model that tells axis that, for this resource
      # (model) you ought to be displaying this "column" as defined by this call
      # with the format/specification defined therein (unless otherwise
      # specified by the call to the helper that renders table(s) of resources).
      #
      def axis_column_on(*args, &block)
        # All attributes who's values are used to build this columns value.
        # Whether this logical column should be one of the "sortable" columns
        # or not. You make it sortable by either passing true for :sort, in
        # which case it will try to sort by all attributes in the order they
        # were passed in, always ASC or DESC together, or by passing an array
        # that defines which attributes will be involved in sorting, the order
        # of priority of the columns, and which direction for overall ASC or
        # DESC respectively that each attribute should sort by.
        # Optional block used to format (and combine) the data from the one or
        # more attributes that make up this column into a single data object to
        # be output (DO NOT try to render into HTML or other markup here -- only
        # transform out to a single, combined data object)
        #
        # Example: real attribute "first", "middle" and "last" (name). Hand-coded
        #   attribute reader method named "name" that outputs the full name (first
        #   middle and last combined).
        #
        #   For all puposes, :rev <=> :reverse, :asc <=> :ascending, and
        #      :desc <=> :descending (alias pairs)
        #
        # axis_column_on :first                          # display this attribute's value in column w/header "First" (unsortable)
        # axis_column_on :first, :sort => false          # same as above (explicitely disable sorting)
        # axis_column_on :first, :sort => true           # same as above, enable sorting
        # axis_column_on :first, :sort => :asc           # same as above, may only ever sort in ascending order
        # axis_column_on :first, :sort => :desc          # same as above, may only ever sort in descending order
        # axis_column_on :first, :sort => :rev           # same as above, always sort in reverse of requested order
        # axis_column_on :first, :sort => [:asc]         # same as| :sort => :asc
        # axis_column_on :first, :sort => [:desc]        # same as| :sort => :desc
        # axis_column_on :first, :sort => [:rev]         # same as| :sort => :rev
        # axis_column_on :first, :sort => [:asc, :asc]   # same as| :sort => :asc
        # axis_column_on :first, :sort => [:asc, :desc]  # same as| :sort => true
        # axis_column_on :first, :sort => [:desc, :asc]  # same as| :sort => :rev
        # axis_column_on :first, :sort => [:desc, :desc] # same as| :sort => :desc
        # axis_column_on :first, :name => "First Name"   # display this attribute's value in column w/header "First Name" (unsortable)
        #
        # axis_column_on :first, :last # display these two attribute's values (concatenated after #to_s) in column w/header "First Last" (unsortable)
        # axis_column_on :first, :last, :name => "Full Name" # same as above but header is "Full Name"
        # axis_column_on :first, :last, :sort => true # same as two above, sorting enabled (by :first then :last, both :asc/:desc together)
        # axis_column_on :first, :last, :sort => :asc # same as above, may only ever sort in ascending order (both are :asc always)
        # axis_column_on :first, :last, :sort => :rev # same as above, always sort in reverse of requested order
        # axis_column_on :first, :last, :sort => [:asc, :asc] # same as| :sort => :asc
        # axis_column_on :first, :last, :sort => [:last, :first] # aHa! same as| :sort => true except we sort by :last, then :first
        # axis_column_on :first, :last, :sort => [{:last => :asc}, {:first => :rev}]
        #   # this one sorts by the :last attribute, then the :first attribute. regardless of the sort order requested,
        #   # it will always sort the :last attribute in ascending order. however, the :first attribute will respect the
        #   # sort order requested but will do so in reverse (ascending when descending requested, etc).
        # axis_column_on :first, :last, :sort => [[:last, :asc], [:first, :rev]] # same as above
        # axis_column_on :first, :last, :sort => [[:last, :asc, :asc], {:first => :rev}] # same as above
        #
        # axis_column_on :first, :middle, :last, :sort => [:first, :last], :name => "Full Name" do |f, m, l|
        #   [f, m, l].join(" ")
        # end
        #   # this will display the three attributes, :first, :middle, and :last as processed by the provided
        #   # block (joined together w/a space between) in a column w/header "Full Name" that is sortable (does
        #   # so using :first then :last attributes, both always in the requested sort order).
        #
        # axis_column_on :name # display result of #name by default (unsortable), column header is "Name"
        # axis_column_on :name, :sort => [:last, :first] # you may sort by :name column, sorts first by last then first name
        # axis_column_on :name, :sort => [:last, [:first, :asc]] # first is always ASC sort order
        # axis_column_on :name, :sort => [:last, [:first, :asc, :desc]] # same as [:last, :first], just explicit
        # axis_column_on :name, :sort => [:last, [:first, :desc]] # first always DESC sort order
        # axis_column_on :name, :sort => [:last, [:first, :desc, :asc]] # first always sorted reverse of last
        # axis_column_on :name, :sort => [[:last, :desc, :asc], :first] # last logically sorts backward of requested order while :first sorts normal
        #
        #
      end

    end # module ClassMethods
  end   # module Model
end     # module Axis
