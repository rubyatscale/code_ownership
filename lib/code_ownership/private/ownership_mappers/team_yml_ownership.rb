# frozen_string_literal: true

# typed: true

module CodeOwnership
  module Private
    module OwnershipMappers
      class TeamYmlOwnership
        extend T::Sig
        include Mapper

        @@map_files_to_owners = T.let(@map_files_to_owners, T.nilable(T::Hash[String, ::CodeTeams::Team])) # rubocop:disable Style/ClassVars
        @@map_files_to_owners = {} # rubocop:disable Style/ClassVars

        sig do
          params(files: T::Array[String])
          .returns(T::Hash[String, ::CodeTeams::Team])
        end
        def map_files_to_owners(files)
          return @@map_files_to_owners if @@map_files_to_owners&.keys && @@map_files_to_owners.keys.count.positive?

          @@map_files_to_owners = CodeTeams.all.each_with_object({}) do |team, map| # rubocop:disable Style/ClassVars
            map[team.config_yml] = team
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
          override.params(files: T::Array[String])
            .returns(T::Hash[String, ::CodeTeams::Team])
        end
        def globs_to_owner(files)
          CodeTeams.all.each_with_object({}) do |team, map|
            map[team.config_yml] = team
          end
        end

        sig { override.void }
        def bust_caches!
          @@map_files_to_owners = {} # rubocop:disable Style/ClassVars
        end

        sig do
          override.params(cache: GlobsToOwningTeamMap, files: T::Array[String]).returns(GlobsToOwningTeamMap)
        end
        def update_cache(cache, files)
          globs_to_owner(files)
        end

        sig { override.returns(String) }
        def description
          'Team YML ownership'
        end
      end
    end
  end
end
