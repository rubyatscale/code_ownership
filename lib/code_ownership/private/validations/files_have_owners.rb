# typed: strict

module CodeOwnership
  module Private
    module Validations
      class FilesHaveOwners
        extend T::Sig
        extend T::Helpers
        include Validator

        sig { override.params(files: T::Array[String], autocorrect: T::Boolean, stage_changes: T::Boolean).returns(T::Array[String]) }
        def validation_errors(files:, autocorrect: true, stage_changes: true)
          allow_list = Dir.glob(Private.configuration.unowned_globs)
          files_by_mapper = Private.glob_cache.files_by_mapper

          files_not_mapped_at_all = files.select do |file|
            files_by_mapper.fetch(file, []).count == 0
          end

          files_without_owners = files_not_mapped_at_all - allow_list

          errors = T.let([], T::Array[String])

          if files_without_owners.any?
            errors << <<~MSG
              Some files are missing ownership:

              #{files_without_owners.map { |file| "- #{file}" }.join("\n")}
            MSG
          end

          errors
        end
      end
    end
  end
end
