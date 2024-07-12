# frozen_string_literal: true

# typed: true

module CodeOwnership
  module Private
    module OwnershipMappers
      class TeamGlobs
        extend T::Sig
        include Mapper
        include Validator

        @@map_files_to_owners = T.let(@map_files_to_owners, T.nilable(T::Hash[String, ::CodeTeams::Team])) # rubocop:disable Style/ClassVars
        @@map_files_to_owners = {} # rubocop:disable Style/ClassVars

        sig do
          params(files: T::Array[String])
          .returns(T::Hash[String, ::CodeTeams::Team])
        end
        def map_files_to_owners(files)
          return @@map_files_to_owners if @@map_files_to_owners&.keys && @@map_files_to_owners.keys.count.positive?

          @@map_files_to_owners = CodeTeams.all.each_with_object({}) do |team, map| # rubocop:disable Style/ClassVars
            TeamPlugins::Ownership.for(team).owned_globs.each do |glob|
              Dir.glob(glob).each do |filename|
                map[filename] = team
              end
            end
          end
        end

        class MappingContext < T::Struct
          const :glob, String
          const :team, CodeTeams::Team
        end

        class GlobOverlap < T::Struct
          extend T::Sig

          const :mapping_contexts, T::Array[MappingContext]

          sig { returns(String) }
          def description
            # These are sorted only to prevent non-determinism in output between local and CI environments.
            sorted_contexts = mapping_contexts.sort_by { |context| context.team.config_yml.to_s }
            description_args = sorted_contexts.map do |context|
              "`#{context.glob}` (from `#{context.team.config_yml}`)"
            end

            description_args.join(', ')
          end
        end

        sig do
          returns(T::Array[GlobOverlap])
        end
        def find_overlapping_globs
          mapped_files = T.let({}, T::Hash[String, T::Array[MappingContext]])
          CodeTeams.all.each_with_object({}) do |team, _map|
            TeamPlugins::Ownership.for(team).owned_globs.each do |glob|
              Dir.glob(glob).each do |filename|
                mapped_files[filename] ||= []
                T.must(mapped_files[filename]) << MappingContext.new(glob: glob, team: team)
              end
            end
          end

          overlaps = T.let([], T::Array[GlobOverlap])
          mapped_files.each_value do |mapping_contexts|
            if mapping_contexts.count > 1
              overlaps << GlobOverlap.new(mapping_contexts: mapping_contexts)
            end
          end

          overlaps.uniq do |glob_overlap|
            glob_overlap.mapping_contexts.map do |context|
              [context.glob, context.team.name]
            end
          end
        end

        sig do
          override.params(file: String)
            .returns(T.nilable(::CodeTeams::Team))
        end
        def map_file_to_owner(file)
          map_files_to_owners([file])[file]
        end

        sig do
          override.params(cache: GlobsToOwningTeamMap, files: T::Array[String]).returns(GlobsToOwningTeamMap)
        end
        def update_cache(cache, files)
          globs_to_owner(files)
        end

        sig do
          override.params(files: T::Array[String])
            .returns(T::Hash[String, ::CodeTeams::Team])
        end
        def globs_to_owner(files)
          CodeTeams.all.each_with_object({}) do |team, map|
            TeamPlugins::Ownership.for(team).owned_globs.each do |owned_glob|
              map[owned_glob] = team
            end
          end
        end

        sig { override.void }
        def bust_caches!
          @@map_files_to_owners = {} # rubocop:disable Style/ClassVars
        end

        sig { override.returns(String) }
        def description
          'Team-specific owned globs'
        end

        sig { override.params(files: T::Array[String], autocorrect: T::Boolean, stage_changes: T::Boolean).returns(T::Array[String]) }
        def validation_errors(files:, autocorrect: true, stage_changes: true)
          overlapping_globs = OwnershipMappers::TeamGlobs.new.find_overlapping_globs

          errors = T.let([], T::Array[String])

          if overlapping_globs.any?
            errors << <<~MSG
              `owned_globs` cannot overlap between teams. The following globs overlap:

              #{overlapping_globs.map { |overlap| "- #{overlap.description}" }.join("\n")}
            MSG
          end

          errors
        end
      end
    end
  end
end
