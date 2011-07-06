# encoding: utf-8
module Axis
  class Session
    class Form
      class Filter
        class Pattern

          #
          # Define what aliases we support for our special query character-
          # matching symbols: "%" and "_"
          #
          ALIASES = { "*".freeze => "%".freeze }.freeze

          #
          # Apply this filter on the provided scope
          #
          def apply(scope)
            if apply?
              field = negated? ? :field.does_not_match : :field.matches
              scope.where(field => unaliased_pattern)
            else
              scope
            end
          end

          #
          # Update the form's filter according to the provided "changes". Returns
          # a boolean indicating whether any changes were made or not.
          #
          def update(changes = nil)
            new_pattern = changes[:pattern] rescue nil
            new_pattern = nil unless new_pattern.is_a?(String) and !new_pattern.blank?
            result      = new_pattern != pattern
            pattern     = new_pattern
            # Call the super-class implementation to do any common work
            super ? true : result
          end

          private

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
          #   unaliased_pattern => "% * *%"
          #
          def unaliased_pattern
            ALIASES.each do |orig, dest|
              pattern.gsub(Regexp.new(Regexp.escape(orig) + "{1,2}")) { $& == orig ? dest : orig }
            end
          end

        end # class  Pattern
      end   # class  Filter
    end     # class  Form
  end       # class  Session
end         # module Axis
