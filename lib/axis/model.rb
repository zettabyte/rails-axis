# encoding: utf-8
module Axis
  module Model

    #
    # Add our class methods too.
    #
    def self.included(base)
      base.send(:extend, ClassMethods)
    end

    module ClassMethods

      def axis_on(*args, &block)
        Attribute.create(self, *args, &block)
      end
      alias_method :axis_attribute_on, :axis_on

      #
      # Define a model attribute (literal or logical) as being visible by the
      # Axis system. If the attribute already has an associate Axis::Attribute
      # storing metadata for it, then this will just modify the existing meta-
      # data. Otherwise it will create a new Axis::Attribute instance to store
      # this metadata for the attribute.
      #
      def axis_display_on(*args, &block)
        Attribute.displayable(self, *args, &block)
      end

      #
      # Define a model attribute (literal or logical) as being sortable by the
      # Axis system. If the attribute already has an associate Axis::Attribute
      # storing metadata for it, then this will just modify the existing meta-
      # data. Otherwise it will create a new Axis::Attribute instance to store
      # this metadata for the attribute.
      #
      # You may include
      #
      def axis_sort_on(*args, &block)
        Attribute.sortable(self, *args, &block)
      end

      #
      # Define a model attribute (literal or logical) as being searchable by the
      # Axis system. If the attribute already has an associate Axis::Attribute
      # storing metadata for it, then this will just modify the existing meta-
      # data. Otherwise it will create a new Axis::Attribute instance to store
      # this metadata for the attribute.
      #
      # If defining settings for a logical attribute that uses several source
      # attributes, you must define the attribute's data :type. The type must be
      # one of the ActiveRecord column types (or an equivalent alias; see
      # Axis::Attribute::TYPES and Axis::Attribute::ALIASES).
      #
      # One of the primary and most useful options is the :filter type option.
      # This is used by axis view helpers to determine what kind of filter UI to
      # draw and filtering options to provide on the attribute. If you don't
      # specify a :filter option, then :filter => :default is used.
      #
      # The value of :filter determines what other options you may provide. For
      # example, the :set value makes the method also check if there is an
      # option named :multi in case you want a "Multi-Set".
      #
      # Example: Multi-Set Column on a :string Field (Literal Column)
      #   axis_search_on :category, :filter => :set, :multi => true,
      #                  :values => %w{ suspense sci-fi fantasy mystery ... }
      #
      # So, the set of recognized options depends on the value of :filter and on
      # the data type (or provided :type) of the attribute. For this reason, the
      # list of available options will first be listed and briefly described for
      # completeness. Then there will be seperate lists and extra descriptions
      # organized by various combinations of data :type and :filter values.
      #
      # == Options ==
      #
      #   :type   | Logical attribute's data-type (don't specify for literal)
      #   :name   | Logical attribute's name (ditto)
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
      # If :filter is :default (the default) then the default "equality" filter
      # is used to search on the attribute. For most data types, this allows the
      # user to enter a value in a text input box. They may also have a listbox
      # from which they can instead select their value or additionally select a
      # comparison type.
      #
      # ==== :string types: (:text or :string) ====
      #
      # You can provide the :not, :null, :blank, and :empty options as desired.
      # After the attribute's name (and optional "not" checkbox) a listbox is
      # displayed with the following values in the following order and with the
      # first option pre-selected (no blank entry):
      #
      #   Matches     | does string equality comparison
      #   Starts With | uses: attribute LIKE 'val%'
      #   Ends With   | uses: attribute LIKE '%val'
      #   Contains    | uses: attribute LIKE '%val%'
      #   [Is Blank]  | if :blank is true; ignores value; matches NULL and ""
      #   [Is Unset]  | if :null  is true; ignores value; matches NULL (IS NULL)
      #   [Is Empty]  | if :empty is true; ignores value; matches ""
      #
      # A textbox input gets a search value from the user (which may be ignored
      # in some instances, such is if "Is Blank" is selected). This value is
      # used to compare against the value in the attribute.
      #
      # If no text in entered in the textbox and none of the optional "Is ..."
      # options are selected in the listbox then this filter is ignored.
      #
      # ==== :numeric types: (:numeric, :integer, :float, :decimal, ...) ====
      #
      # For numeric types with a :default value for :filter, you may provide the
      # :not and :null options. The options displayed in the listbox and
      # associated comparisons to the user-entered value are:
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
      # ==== :temporal types: (:temporal, :date, :time, :datetime, ...) ====
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
      # ==== :boolean type: (:boolean or :bool) ====
      #
      # For attributes with a :filter value of :default, :boolean attributes
      # differ from other types the most. There is no text input box, just a
      # single listbox. You can provide the :not and :null options to get a
      # negation (or "not") checkbox and an extra "Unset" option in the listbox
      # respectively. The listbox will have a "true" and "false" option below
      # a first/default blank entry. When the blank entry is selected, this
      # filter is ignored.
      #
      #   <blank> | disables the filter if selected
      #   True    | searches where this attribute is true
      #   False   | searches where this attribute is false
      #   [Unset] | searches where this attribute IS NULL
      #
      # === Filter Type: :set ===
      #
      # If the :filter is :set then a listbox is used to display one or more
      # values, provided by the :values option, that the user can select. Only
      # records where the attribute matches the selected value are displayed.
      #
      # You can use this filter type for all attribute types except :boolean.
      # If used, the following options are recognized: :not, :null, :blank,
      # :empty, :multi and :values. However, :blank and :empty are only valid
      # if the attribute's :type is one of the :string types.
      #
      # The :null, :blank, and :empty options add "Unset", "Blank", and "Empty"
      # values to the listbox is present.
      #
      # If :multi is true, then the listbox will support multi-selection and a
      # given record will match the filter if the attribute's value matches any
      # one of the selected criterion.
      #
      # === Filter Type: :null ===
      #
      # This filter may be applied to attributes of all types. You may provide
      # the :not and :multi options when using this filter. As always, the :not
      # option adds a negation "not" checkbox. If :multi *IS NOT* provided then
      # the filter will simply renders a single checkbox that, if checked,
      # matches if the attribute IS NOT NULL and if unchecked matches if the
      # attribute IS NULL. As such, this filter always applies (checkboxes can
      # only be in two states).
      #
      # To add a third state, you may provide the :multi option which will
      # instead render two radio buttons (as opposed to a checkbox). One will be
      # labelled "Set" and the other "Unset". Then, if neither is selected (the
      # "third" state) then the filter isn't applied. Otherwise one or the other
      # conditions is checked as with the checkbox (:multi => false).
      #
      # For :string attributes you may also pass the :blank or :empty options
      # (but not both, they're mutually exclusive). If one of these is passed
      # then instead of checking for NULL/NOT NULL, it will check if the
      # attribute is "blank"/"not blank" or is "empty"/"not empty" respectively.
      # A string is "blank" if it is either the empty string ("") or NULL. It is
      # "empty" if it is the empty string (""). The checkbox or radio button
      # labels are modified accordingly.
      #
      # Note that providing the :not option to such a simple filter doesn't make
      # much sense but is supported.
      #
      # === Filter Type: :boolean ===
      #
      # This filter type is only available on :boolean attributes. This offers
      # two more variations for dealing with boolean attributes than available
      # with the listbox provided by the :default filter type. This filter type
      # supports the :not option, yielding a negation "not" checkbox, doubling
      # the number of variations available.
      #
      # This is useful since in databases, boolean comparisons can be more
      # complicated than true boolean comparisons. This is because boolean
      # columns are often be allowed to be NULL. Also, in many DBMS there is no
      # native boolean type: it is just emulated (in this case by ActiveRecord)
      # but there may be several possible values stored in the back-end column
      # besides the official true or false values. Thus, just because a value
      # DOESN'T match your "false" value doesn't mean it's necessarily equal to
      # true. The reverse is also true.
      #
      # So, the first option supported is :multi. Without it, a checkbox is used
      # while with it, two radio buttons are used. With the radio buttons, if
      # neither is selected then the filter is ignored (3rd state). Otherwise
      # if the radio button labelled "True" is checked, then only records with
      # the attribute having the offical true value are returned. If the "False"
      # radio button is checked, only those with the official false value are
      # returned (no NULL or other values). This is important since if your true
      # value is the number 1 and a record erroneously has a value of 2, some
      # might still consider this true but selecting "True" won't pick up this
      # record (neither will "False"). However, if "True" is selected along with
      # the "not" checkbox then it _will_ be selected.
      #
      # If :multi isn't provided (or is false) then a checkbox is used. If
      # checked, true values are returned, unchecked then false ones are. This
      # is just like when the "True" or "False" radio buttons (described above)
      # are checked, respectively.
      #
      # Finally, if :multi is false and you provide the :false option,
      # :multi => false, :false => true (yes, sounds contradictory, I know) then
      # you have another variation. You'll get a checkbox that behaves the same
      # when it is checked, but when it isn't, all records with non-true values
      # are returned (this includes NULL ones). This is opposed to the normal
      # variation where just those having the offical false (usually the number
      # zero) value are returned.
      #
      # === Filter Type: :range ===
      #
      # This filter is supported by all the temporal and numeric attributes.
      # This renders two textboxes in which the user can enter two literal
      # values (that must correspond to the associated attribute's type). This
      # results in the filter selecting all records where the attribute's value
      # is between the two user-provided values (uses the sql BETWEEN clause).
      #
      # This filter supports only the :not option. Also, it is ignored unless
      # both textboxes are filled with valid values (that correspond to the
      # associated attribute's type).
      #
      # === Filter Type: :pattern ===
      #
      # This is a :string-type specific filter (:string and :text attributes).
      # This provides a simple textbox that the user can enter search text into.
      # There are no :blank, :null, or :empty options on this one. Just the :not
      # option.
      #
      # This allows the user to include the special characters "*" (star), "%"
      # (percent), and "_" (underscore) into their search string. The stars are
      # converted to percents. Otherwise, the search string is basically passed
      # through, untouched, to construct an sql "LIKE" clause (sql-injection is
      # still prevendted). This allows the user to have more power when
      # searching on a text attribute by providing arbitrary search patterns.
      #
      # Note that the user can search for literal versions of each of the
      # special characters by doubling them:
      #   "__%% Done" => Matches "23% Done" (the 23 can be any two characters)
      #
      def axis_search_on(*args, &block)
        Attribute.searchable(self, *args, &block)
      end

    end # module ClassMethods
  end   # module Model
end     # module Axis
