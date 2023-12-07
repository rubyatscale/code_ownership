# frozen_string_literal: true

# typed: strict

module CodeOwnership
  module Private
    module OwnershipMappers
      class FileOwner
        extend T::Sig

        sig { returns(String) }
        attr_reader :file_path
        sig { returns(T::Hash[String, T.nilable(CodeTeams::Team)]) }
        attr_reader :directory_cache

        private_class_method :new

        sig { params(file_path: String, directory_cache: T::Hash[String, T.nilable(CodeTeams::Team)]).void }
        def initialize(file_path, directory_cache)
          @file_path = file_path
          @directory_cache = directory_cache
        end

        sig { params(file_path: String, directory_cache: T::Hash[String, T.nilable(CodeTeams::Team)]).returns(T.nilable(CodeTeams::Team)) }
        def self.for_file(file_path, directory_cache)
          new(file_path, directory_cache).owner
        end

        sig { returns(T.nilable(CodeTeams::Team)) }
        def owner
          path_components_end_index.downto(0).each do |index|
            team = team_for_path_components(T.must(path_components[0..index]))
            return team if team
          end
          nil
        end

        sig { params(codeowners_file: Pathname).returns(CodeTeams::Team) }
        def self.owner_for_codeowners_file(codeowners_file)
          raw_owner_value = File.foreach(codeowners_file).first.strip

          Private.find_team!(
            raw_owner_value,
            codeowners_file.to_s
          )
        end

        private

        sig { params(path_components: T::Array[Pathname]).returns(T.nilable(CodeTeams::Team)) }
        def team_for_path_components(path_components)
          potential_relative_path_name = path_components.reduce(Pathname.new('')) do |built_path, path|
            built_path.join(path)
          end

          potential_codeowners_file = potential_relative_path_name.join(DirectoryOwnership::CODEOWNERS_DIRECTORY_FILE_NAME)
          potential_codeowners_file_name = potential_codeowners_file.to_s

          team = nil
          if directory_cache.key?(potential_codeowners_file_name)
            team = directory_cache[potential_codeowners_file_name]
          elsif potential_codeowners_file.exist?
            team = self.class.owner_for_codeowners_file(potential_codeowners_file)
            directory_cache[potential_codeowners_file_name] = team
          else
            directory_cache[potential_codeowners_file_name] = nil
          end

          team
        end

        sig { returns(Pathname) }
        def file_path_name
          T.let(Pathname.new(file_path), T.nilable(Pathname))
          @file_path_name ||= T.let(Pathname.new(file_path), T.nilable(Pathname))
        end

        sig { returns(T::Boolean) }
        def file_is_dir?
          file_path_name.directory?
        end

        sig { returns(Integer) }
        def path_components_end_index
          # include the directory itself if it is a directory, but not if it is a file
          if file_is_dir?
            path_components.length
          else
            path_components.length - 1
          end
        end

        sig { returns(T::Array[Pathname]) }
        def path_components
          file_path_name.each_filename.to_a.map { |path| Pathname.new(path) }
        end
      end
    end
  end
end
