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

          codeowners_up_to_date = actual_content_lines == expected_content_lines
          errors = T.let([], T::Array[String])

          if !codeowners_up_to_date
            if autocorrect
              CodeownersFile.write!
              if stage_changes
                `git add #{CodeownersFile.path}`
              end
            # If there is no current file or its empty, display a shorter message.
            elsif actual_content_lines == ['']
              errors << <<~CODEOWNERS_ERROR
                CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file
              CODEOWNERS_ERROR
            else
              missing_lines = expected_content_lines - actual_content_lines
              extra_lines = actual_content_lines - expected_content_lines

              missing_lines_text = if missing_lines.any?
                                     <<~COMMENT
                                       CODEOWNERS should contain the following lines, but does not:
                                       #{missing_lines.map { |line| "- \"#{line}\"" }.join("\n")}
                                     COMMENT
                                   end

              extra_lines_text = if extra_lines.any?
                                   <<~COMMENT
                                     CODEOWNERS should not contain the following lines, but it does:
                                     #{extra_lines.map { |line| "- \"#{line}\"" }.join("\n")}
                                   COMMENT
                                 end

              diff_text = if missing_lines_text && extra_lines_text
                            "#{missing_lines_text}\n#{extra_lines_text}".chomp
                          elsif missing_lines_text
                            missing_lines_text
                          elsif extra_lines_text
                            extra_lines_text
                          else
                            <<~TEXT
                              There may be extra lines, or lines are out of order.
                              You can try to regenerate the CODEOWNERS file from scratch:
                              1) `rm .github/CODEOWNERS`
                              2) `bin/codeownership validate`
                            TEXT
                          end

              errors << <<~CODEOWNERS_ERROR
                CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file

                #{diff_text.chomp}
              CODEOWNERS_ERROR
            end
          end

          errors
        end
      end
    end
  end
end
