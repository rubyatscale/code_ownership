# typed: strict

module CodeOwnership
  module Private
    module Validations
      class GithubCodeownersUpToDate
        extend T::Sig
        extend T::Helpers
        include Validator

        sig { override.params(files: T::Array[String], autocorrect: T::Boolean, stage_changes: T::Boolean).returns(T::Array[String]) }
        def validation_errors(files:, autocorrect: true, stage_changes: true)
          return [] if Private.configuration.skip_codeowners_validation

          actual_content_lines = CodeownersFile.actual_contents_lines
          expected_content_lines = CodeownersFile.expected_contents_lines
          missing_lines = expected_content_lines - actual_content_lines
          extra_lines = actual_content_lines - expected_content_lines

          codeowners_up_to_date = !missing_lines.any? && !extra_lines.any?
          errors = T.let([], T::Array[String])

          if !codeowners_up_to_date
            if autocorrect
              CodeownersFile.write!
              if stage_changes
                `git add #{CodeownersFile.path}`
              end
            else
              # If there is no current file or its empty, display a shorter message.

              missing_lines_text = if missing_lines.any?
                <<~COMMENT
                  CODEOWNERS should contain the following lines, but does not:
                  #{(missing_lines).map { |line| "- \"#{line}\""}.join("\n")}
                COMMENT
              end

              extra_lines_text = if extra_lines.any?
                <<~COMMENT
                  CODEOWNERS should not contain the following lines, but it does:
                  #{(extra_lines).map { |line| "- \"#{line}\""}.join("\n")}
                COMMENT
              end

              diff_text = if missing_lines_text && extra_lines_text
                 "#{missing_lines_text}\n#{extra_lines_text}".chomp
              elsif missing_lines_text
                missing_lines_text
              elsif extra_lines_text
                extra_lines_text
              else
                ""
              end

              if actual_content_lines == [""]
                errors << <<~CODEOWNERS_ERROR
                  CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file
                CODEOWNERS_ERROR
              else
                errors << <<~CODEOWNERS_ERROR
                  CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file

                  #{diff_text.chomp}
                CODEOWNERS_ERROR
              end
            end
          end

          errors
        end
      end
    end
  end
end
