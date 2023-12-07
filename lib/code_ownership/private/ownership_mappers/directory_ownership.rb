# frozen_string_literal: true

# typed: true

module CodeOwnership
  module Private
    module OwnershipMappers
      class DirectoryOwnership
        extend T::Sig
        include Mapper

        CODEOWNERS_DIRECTORY_FILE_NAME = '.codeowner'

        @@directory_cache = T.let({}, T::Hash[String, T.nilable(CodeTeams::Team)]) # rubocop:disable Style/ClassVars

        sig do
          override.params(file: String)
                  .returns(T.nilable(::CodeTeams::Team))
        end
        def map_file_to_owner(file)
          map_file_to_relevant_owner(file)
        end

        sig do
          override.params(_cache: GlobsToOwningTeamMap, files: T::Array[String]).returns(GlobsToOwningTeamMap)
        end
        def update_cache(_cache, files)
          globs_to_owner(files)
        end

        #
        # Directory ownership ignores the passed in files when generating code owners lines.
        # This is because Directory ownership knows that the fastest way to find code owners for directory based ownership
        # is to simply iterate over the directories and grab the owner, rather than iterating over each file just to get what directory it is in
        # In theory this means that we may generate code owners lines that cover files that are not in the passed in argument,
        # but in practice this is not of consequence because in reality we never really want to generate code owners for only a
        # subset of files, but rather we want code ownership for all files.
        #
        sig do
          override.params(_files: T::Array[String])
                  .returns(T::Hash[String, ::CodeTeams::Team])
        end
        def globs_to_owner(_files)
          # The T.unsafe is because the upstream RBI is wrong for Pathname.glob
          T
            .unsafe(Pathname)
            .glob(File.join('**/', CODEOWNERS_DIRECTORY_FILE_NAME))
            .map(&:cleanpath)
            .each_with_object({}) do |pathname, res|
            owner = FileOwner.owner_for_codeowners_file(pathname)
            res[pathname.dirname.cleanpath.join('**/**').to_s] = owner
          end
        end

        sig { override.returns(String) }
        def description
          'Owner in .codeowner'
        end

        sig { override.void }
        def bust_caches!
          @@directory_cache = {} # rubocop:disable Style/ClassVars
        end

        private

        # takes a file and finds the relevant `.codeowner` file by walking up the directory
        # structure. Example, given `a/b/c.rb`, this looks for `a/b/.codeowner`, `a/.codeowner`,
        # and `.codeowner` in that order, stopping at the first file to actually exist.
        # We do additional caching so that we don't have to check for file existence every time
        sig { params(file: String).returns(T.nilable(CodeTeams::Team)) }
        def map_file_to_relevant_owner(file)
          FileOwner.for_file(file, @@directory_cache)
        end
      end
    end
  end
end
