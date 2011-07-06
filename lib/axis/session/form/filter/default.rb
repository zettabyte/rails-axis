# encoding: utf-8
module Axis
  class Session
    class Form
      class Filter
        class Default

          COMPARISONS = {
            :string   => %w{ equals begins ends    contains                       }.map { |s| s.freeze }.freeze,
            :numeric  => %w{ equals less   greater less_or_equal greater_or_equal }.map { |s| s.freeze }.freeze,
            :temporal => %w{ equals before after   before_or_on  after_or_on      }.map { |s| s.freeze }.freeze,
            :boolean  => %w{ true   false                                         }.map { |s| s.freeze }.freeze
          }.freeze

          LABELS = {
            :string => {
              "equals".freeze   => "Matches".freeze,
              "begins".freeze   => "Starts With".freeze,
              "ends".freeze     => "Ends With".freeze,
              "contains".freeze => "Contains".freeze
            }.freeze,
            :numeric => {
              "equals".freeze           => "Equal To".freeze,
              "less".freeze             => "Less Than".freeze,
              "greater".freeze          => "Greater Than".freeze,
              "less_or_equal".freeze    => "Less Than or Equal To".freeze,
              "greater_or_equal".freeze => "Greater Than or Equal To".freeze
            }.freeze,
            :temporal => {
              "equals".freeze       => "Equal To".freeze,
              "before".freeze       => "Before".freeze,
              "after".freeze        => "After".freeze,
              "before_or_on".freeze => "Before or On".freeze,
              "after_or_on".freeze  => "After or On".freeze
              }.freeze,
            :boolean => {
              "true".freeze  => "True".freeze,
              "false".freeze => "False".freeze
              }.freeze
          }.freeze

          SPECIALS = {
            :comparisons => %w{ null empty blank }.map { |s| s.freeze }.freeze,
            :labels      => {
              "null".freeze  => "Is Unset".freeze,
              "empty".freeze => "Is Empty".freeze,
              "blank".freeze => "Is Blank".freeze
            }.freeze
          }

          #
          # Return an array (of two-element arrays) containing the appropriate
          # list of values and display names for a filter of type :default's
          # comparison-selection options.
          #
          def comparison_options
            result = COMPARISONS[attribute_type].map { |c| [LABELS[attribute_type][c], c] }
            result.unshift(["", ""]) if attribute_type == :boolean
            SPECIALS[:comparisons].each do |c|
              result << [c, SPECIALS[:labels][c]] if self.send("include_#{c}?")
            end
            result
          end

          #
          # This gets a formatted, displayable string version of #value. It will
          # apply any custom formatter for the filter value and optionally
          # "hide" it (by returning an empty string) in cases where the value
          # should simply be ignored.
          #
          def rendered_value
            result = value.to_s
            # TODO: implement custom formatter block (in attribute filter
            #       definitions) to control how non-string type values get
            #       formatted to strings for display
            if comparison.blank? or SPECIALS[:comparisons].include?(comparison) or attribute_type == :boolean
              ""
            else
              result
            end
          end

          #
          # Returns true if template code should draw a "value" text box in
          # addition to the comparison select box or not.
          #
          def include_value?
            attribute_type != :boolean
          end

          private

          #
          # Generate a hash representing an individual sql WHERE-clause (using
          # the MetaWhere gem features) for this filter on the provided column
          # name.
          #
          # If the filter doesn't apply then just return nil.
          #
          def where_clause(column)
            return nil unless apply?
            column = column.intern
            if SPECIALS[:comparisons].include?(comparison)
              column = column.not_eq if negated? # pre-apply negation
              case comparison
              when "null"  then { column => nil }
              when "empty" then { column => ""  }
              when "blank"
                if negated?
                  { column => nil } & { column => "" } # column already #not_eq
                else
                  { column => nil } | { column => "" }
                end
              end
            elsif comparison == "equals"           or attribute_type == :boolean
              { (negated? ? column.not_eq : column ) => value }
            elsif comparison == "less"             or comparison == "before"
              { (negated? ? column.gteq : column.lt) => value }
            elsif comparison == "greater"          or comparison == "after"
              { (negated? ? column.lteq : column.gt) => value }
            elsif comparison == "less_or_equal"    or comparison == "before_or_on"
              { (negated? ? column.gt : column.lteq) => value }
            elsif comparison == "greater_or_equal" or comparison == "after_or_on"
              { (negated? ? column.lt : column.gteq) => value }
            elsif comparison == "begins" or comparison == "ends" or comparison == "contains"
              pattern = case comparison
              when "begins"   then  "#{escaped_value}%"
              when "ends"     then "%#{escaped_value}"
              when "contains" then "%#{escaped_value}%"
              end
              { (negated? ? column.not_matches : column.matches) => pattern }
            else
              nil
            end
          end

          #
          # Update the form's filter according to the provided "changes". Returns
          # a boolean indicating whether any changes were made or not.
          #
          def private_update(changes)
            new_comparison = changes[:comparison]
            new_value      = changes[:value]
            result         = new_comparison != comparison
            if new_comparison.blank?
              result     = apply? # a change occured if old filter "applied"
              value      = nil
              comparison = nil
            elsif SPECIALS[:comparisons].include?(new_comparison)
              comparison = new_comparison
              value      = true # so that #apply? works; value ignored
            elsif COMPARISONS[attribute_type].include?(new_comparison)
              # convert new_value to correct data type
              new_value = case attribute_type
              when :string  then new_value == "" ? nil : new_value
              when :numeric then Validate.numeric(new_value)
              when :boolean then new_comparison == "true" # set #value from #comparison
              when :temporal
                tmp = Validate.temporal(new_value)
                attribute.type == :date ? tmp.to_date : tmp
              end rescue nil
              result   ||= new_value != value
              comparison = new_comparison
              value      = new_value
            end
            result
          end

          #
          # After a new state filter is created it might not have the best set
          # of default values since it isn't aware of the associated attribute's
          # settings. This is called when the state filter is first constructed
          # and "wrapped" by the session filter to set up these context-aware
          # defaults.
          #
          def initial_defaults
          end

          #
          # Escape any '%' or '_' in value so they'll be matched literally.
          #
          def escaped_value
            value.gsub(/[%_]/, "\\&\\&")
          end

        end # class  Default
      end   # class  Filter
    end     # class  Form
  end       # class  Session
end         # module Axis
