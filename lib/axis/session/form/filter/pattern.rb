# encoding: utf-8
module Axis
  class Session
    class Form
      class Filter
        class Pattern < Filter

          # Define what aliases we support for our special query character-
          # matching symbols: "%" and "_"
          ALIASES = { "*".freeze => "%".freeze }.freeze

          #
          # After a new state filter is created it might not have the best set
          # of default values since it isn't aware of the associated attribute's
          # settings. This is called when the state filter is first constructed
          # and "wrapped" by the session filter to set up these context-aware
          # defaults.
          #
          def initialize_defaults!
            # default state is all empty
          end

          #
          # This gets the display version of #value
          #
          def rendered_value
            value.blank? ? "" : value
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
            column = column.intern
            { (negated? ? column.not_matches : column.matches) => unaliased_value }
          end

          #
          # Update the form's filter according to the provided "changes". Returns
          # a boolean indicating whether any changes were made or not.
          #
          def private_update(changes)
            new_value  = changes[:value]
            new_value  = nil if new_value.blank?
            result     = new_value != value
            self.value = new_value
            result
          end

          #
          # For each entry in ALIASES, unalias any single sequences of the alias
          # string (the key) to the destination string (the value). When the
          # sequence is doubled, however, treat it as an escape sequence for the
          # alias string itself so unescape the sequence.
          #
          # Given:
          #   ALIASES => { "*" => "%" }
          #   pattern => "* ** ***"
          # Then:
          #   unaliased_value => "% * *%"
          #
          def unaliased_value
            ALIASES.each do |orig, dest|
              pattern.gsub(Regexp.new(Regexp.escape(orig) + "{1,2}")) { $& == orig ? dest : orig }
            end
          end

        end # class  Pattern
      end   # class  Filter
    end     # class  Form
  end       # class  Session
end         # module Axis
