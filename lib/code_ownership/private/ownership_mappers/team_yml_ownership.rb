# frozen_string_literal: true

# typed: true

module CodeOwnership
  module Private
    module OwnershipMappers
      class TeamYmlOwnership
        extend T::Sig
        include Interface

        @@map_files_to_owners = T.let(@map_files_to_owners, T.nilable(T::Hash[String, T.nilable(::CodeTeams::Team)])) # rubocop:disable Style/ClassVars
        @@map_files_to_owners = {} # rubocop:disable Style/ClassVars
        @@codeowners_lines_to_owners = T.let(@codeowners_lines_to_owners, T.nilable(T::Hash[String, T.nilable(::CodeTeams::Team)])) # rubocop:disable Style/ClassVars
        @@codeowners_lines_to_owners = {} # rubocop:disable Style/ClassVars

        sig do
          override.
            params(files: T::Array[String]).
            returns(T::Hash[String, T.nilable(::CodeTeams::Team)])
        end
        def map_files_to_owners(files) # rubocop:disable Lint/UnusedMethodArgument
          return @@map_files_to_owners if @@map_files_to_owners&.keys && @@map_files_to_owners.keys.count > 0

          @@map_files_to_owners = CodeTeams.all.each_with_object({}) do |team, map| # rubocop:disable Style/ClassVars
            map[team.config_yml] = team
          end
        end

        sig do
          override.params(file: String).
            returns(T.nilable(::CodeTeams::Team))
        end
        def map_file_to_owner(file)
          map_files_to_owners([file])[file]
        end

        sig do
          override.returns(T::Hash[String, T.nilable(::CodeTeams::Team)])
        end
        def codeowners_lines_to_owners
          return @@codeowners_lines_to_owners if @@codeowners_lines_to_owners&.keys && @@codeowners_lines_to_owners.keys.count > 0

          @@codeowners_lines_to_owners = CodeTeams.all.each_with_object({}) do |team, map| # rubocop:disable Style/ClassVars
            map[team.config_yml] = team
          end
        end

        sig { override.void }
        def bust_caches!
          @@codeowners_lines_to_owners = {} # rubocop:disable Style/ClassVars
          @@map_files_to_owners = {} # rubocop:disable Style/ClassVars
        end

        sig { override.returns(String) }
        def description
          'Team YML ownership'
        end
      end
    end
  end
end
