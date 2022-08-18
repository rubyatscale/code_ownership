# frozen_string_literal: true

# typed: true

module CodeOwnership
  module Private
    module OwnershipMappers
      class PackageOwnership
        extend T::Sig
        include Interface

        @@package_yml_cache = T.let({}, T::Hash[String, T.nilable(ParsePackwerk::Package)]) # rubocop:disable Style/ClassVars

        sig do
          override.params(file: String).
            returns(T.nilable(::CodeTeams::Team))
        end
        def map_file_to_owner(file)
          package = ParsePackwerk.package_from_path(file)

          return nil if package.nil?

          owner_for_package(package)
        end

        sig do
          override.
            params(files: T::Array[String]).
            returns(T::Hash[String, T.nilable(::CodeTeams::Team)])
        end
        def map_files_to_owners(files) # rubocop:disable Lint/UnusedMethodArgument
          ParsePackwerk.all.each_with_object({}) do |package, res|
            owner = owner_for_package(package)
            next if owner.nil?

            glob = package.directory.join('**/**').to_s
            Dir.glob(glob).each do |path|
              res[path] = owner
            end
          end
        end

        #
        # Package ownership ignores the passed in files when generating code owners lines.
        # This is because Package ownership knows that the fastest way to find code owners for package based ownership
        # is to simply iterate over the packages and grab the owner, rather than iterating over each file just to get what package it is in
        # In theory this means that we may generate code owners lines that cover files that are not in the passed in argument,
        # but in practice this is not of consequence because in reality we never really want to generate code owners for only a
        # subset of files, but rather we want code ownership for all files.
        #
        sig do
          override.returns(T::Hash[String, T.nilable(::CodeTeams::Team)])
        end
        def codeowners_lines_to_owners
          ParsePackwerk.all.each_with_object({}) do |package, res|
            owner = owner_for_package(package)
            next if owner.nil?

            res[package.directory.join('**/**').to_s] = owner
          end
        end

        sig { override.returns(String) }
        def description
          'Owner metadata key in package.yml'
        end

        sig { params(package: ParsePackwerk::Package).returns(T.nilable(CodeTeams::Team)) }
        def owner_for_package(package)
          raw_owner_value = package.metadata['owner']
          return nil if !raw_owner_value

          Private.find_team!(
            raw_owner_value,
            package.yml.to_s
          )
        end

        sig { override.void }
        def bust_caches!
          @@package_yml_cache = {} # rubocop:disable Style/ClassVars
        end
      end
    end
  end
end
