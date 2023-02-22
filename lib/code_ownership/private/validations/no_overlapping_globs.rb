# typed: strict

module CodeOwnership
  module Private
    module Validations
      class NoOverlappingGlobs
        extend T::Sig
        extend T::Helpers
        include Interface

        sig { override.params(files: T::Array[String], autocorrect: T::Boolean, stage_changes: T::Boolean).returns(T::Array[String]) }
        def validation_errors(files:, autocorrect: true, stage_changes: true)
          overlapping_globs = OwnershipMappers::TeamGlobs.new.find_overlapping_globs

          errors = T.let([], T::Array[String])

          if overlapping_globs.any?
            errors << <<~MSG
              `owned_globs` cannot overlap between teams. The following globs overlap:

              #{overlapping_globs.map { |overlap| "- #{overlap.description}"}.join("\n")}
            MSG
          end

          errors
        end
      end
    end
  end
end
