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
          cache = Private.glob_cache
          file_mappings = cache.mapper_descriptions_that_map_files(files)
          files_not_mapped_at_all = file_mappings.select do |_file, mapper_descriptions|
            mapper_descriptions.none?
          end

          errors = T.let([], T::Array[String])

          if files_not_mapped_at_all.any?
            errors << <<~MSG
              Some files are missing ownership:

              #{files_not_mapped_at_all.map { |file, _mappers| "- #{file}" }.join("\n")}
            MSG
          end

          errors
        end
      end
    end
  end
end
