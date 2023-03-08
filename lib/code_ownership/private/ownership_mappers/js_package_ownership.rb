# frozen_string_literal: true

# typed: true

module CodeOwnership
  module Private
    module OwnershipMappers
      class JsPackageOwnership
        extend T::Sig
        include Mapper

        @@package_json_cache = T.let({}, T::Hash[String, T.nilable(ParseJsPackages::Package)]) # rubocop:disable Style/ClassVars

        sig do
          override.params(file: String).
            returns(T.nilable(::CodeTeams::Team))
        end
        def map_file_to_owner(file)
          package = map_file_to_relevant_package(file)

          return nil if package.nil?

          owner_for_package(package)
        end

        sig do
          override.
            params(files: T::Array[String]).
            returns(T::Hash[String, T.nilable(::CodeTeams::Team)])
        end
        def map_files_to_owners(files) # rubocop:disable Lint/UnusedMethodArgument
          ParseJsPackages.all.each_with_object({}) do |package, res|
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
          ParseJsPackages.all.each_with_object({}) do |package, res|
            owner = owner_for_package(package)
            next if owner.nil?

            res[package.directory.join('**/**').to_s] = owner
          end
        end

        sig { override.returns(String) }
        def description
          'Owner metadata key in package.json'
        end

        sig { params(package: ParseJsPackages::Package).returns(T.nilable(CodeTeams::Team)) }
        def owner_for_package(package)
          raw_owner_value = package.metadata['owner']
          return nil if !raw_owner_value

          Private.find_team!(
            raw_owner_value,
            package.name
          )
        end

        sig { override.void }
        def bust_caches!
          @@package_json_cache = {} # rubocop:disable Style/ClassVars
        end

        private

        # takes a file and finds the relevant `package.json` file by walking up the directory
        # structure. Example, given `packages/a/b/c.rb`, this looks for `packages/a/b/package.json`, `packages/a/package.json`,
        # `packages/package.json`, and `package.json` in that order, stopping at the first file to actually exist.
        # We do additional caching so that we don't have to check for file existence every time
        sig { params(file: String).returns(T.nilable(ParseJsPackages::Package)) }
        def map_file_to_relevant_package(file)
          file_path = Pathname.new(file)
          path_components = file_path.each_filename.to_a.map { |path| Pathname.new(path) }

          (path_components.length - 1).downto(0).each do |i|
            potential_relative_path_name = T.must(path_components[0...i]).reduce(Pathname.new('')) { |built_path, path| built_path.join(path) }
            potential_package_json_path = potential_relative_path_name.
              join(ParseJsPackages::PACKAGE_JSON_NAME)

            potential_package_json_string = potential_package_json_path.to_s

            package = nil
            if @@package_json_cache.key?(potential_package_json_string)
              package = @@package_json_cache[potential_package_json_string]
            elsif potential_package_json_path.exist?
              package = ParseJsPackages::Package.from(potential_package_json_path)

              @@package_json_cache[potential_package_json_string] = package
            else
              @@package_json_cache[potential_package_json_string] = nil
            end

            return package unless package.nil?
          end

          nil
        end
      end
    end
  end
end
