# typed: strict

module CodeOwnership
  module Private
    module Validations
      class FilesHaveUniqueOwners
        extend T::Sig
        extend T::Helpers
        include Validator

        sig { override.params(files: T::Array[String], autocorrect: T::Boolean, stage_changes: T::Boolean).returns(T::Array[String]) }
        def validation_errors(files:, autocorrect: true, stage_changes: true)
          cache = Private.glob_cache
          file_mappings = cache.mapper_descriptions_that_map_files(files)
          files_mapped_by_multiple_mappers = file_mappings.select do |_file, mapper_descriptions|
            mapper_descriptions.count > 1
          end

          errors = T.let([], T::Array[String])

          if files_mapped_by_multiple_mappers.any?
            errors << <<~MSG
              Code ownership should only be defined for each file in one way. The following files have declared ownership in multiple ways.

              #{files_mapped_by_multiple_mappers.map { |file, descriptions| "- #{file} (#{descriptions.to_a.join(', ')})" }.join("\n")}
            MSG
          end

          errors
        end
      end
    end
  end
end
