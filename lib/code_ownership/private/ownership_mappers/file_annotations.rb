# frozen_string_literal: true

# typed: strict

module CodeOwnership
  module Private
    module OwnershipMappers
      # Calculate, cache, and return a mapping of file names (relative to the root
      # of the repository) to team name.
      #
      # Example:
      #
      #   {
      #     'app/models/company.rb' => Team.find('Setup & Onboarding'),
      #     ...
      #   }
      class FileAnnotations
        extend T::Sig
        include Mapper

        @@map_files_to_owners = T.let({}, T.nilable(T::Hash[String, ::CodeTeams::Team])) # rubocop:disable Style/ClassVars

        TEAM_PATTERN = T.let(/\A(?:#|\/\/) @team (?<team>.*)\Z/.freeze, Regexp)
        DESCRIPTION = 'Annotations at the top of file'

        sig do
          override.params(file: String).
            returns(T.nilable(::CodeTeams::Team))
        end
        def map_file_to_owner(file)
          file_annotation_based_owner(file)
        end

        sig do
          override.
            params(files: T::Array[String]).
            returns(T::Hash[String, ::CodeTeams::Team])
        end
        def globs_to_owner(files)
          return @@map_files_to_owners if @@map_files_to_owners&.keys && @@map_files_to_owners.keys.count > 0

          @@map_files_to_owners = files.each_with_object({}) do |filename_relative_to_root, mapping| # rubocop:disable Style/ClassVars
            owner = file_annotation_based_owner(filename_relative_to_root)
            next unless owner

            mapping[filename_relative_to_root] = owner
          end
        end

        sig do
          override.params(cache: GlobsToOwningTeamMap, files: T::Array[String]).returns(GlobsToOwningTeamMap)
        end
        def update_cache(cache, files)
          cache.merge!(globs_to_owner(files))
          invalid_files = cache.keys.select do |file|
            !Private.file_tracked?(file)
          end
          invalid_files.each do |invalid_file|
            cache.delete(invalid_file)
          end

          cache
        end

        sig { params(filename: String).returns(T.nilable(CodeTeams::Team)) }
        def file_annotation_based_owner(filename)
          # If for a directory is named with an ownable extension, we need to skip
          # so File.foreach doesn't blow up below. This was needed because Cypress
          # screenshots are saved to a folder with the test suite filename.
          return if File.directory?(filename)
          return unless File.file?(filename)

          # The annotation should be on line 1 but as of this comment
          # there's no linter installed to enforce that. We therefore check the
          # first line (the Ruby VM makes a single `read(1)` call for 8KB),
          # and if the annotation isn't in the first two lines we assume it
          # doesn't exist.

          line_1 = File.foreach(filename).first

          return if !line_1

          begin
            team = line_1[TEAM_PATTERN, :team]
          rescue ArgumentError => ex
            if ex.message.include?('invalid byte sequence')
              team = nil
            else
              raise
            end
          end

          return unless team

          Private.find_team!(
            team,
            filename
          )
        end

        sig { params(filename: String).void }
        def remove_file_annotation!(filename)
          if file_annotation_based_owner(filename)
            filepath = Pathname.new(filename)
            lines = filepath.read.split("\n")
            new_lines = lines.select { |line| !line[TEAM_PATTERN] }
            # We explicitly add a final new line since splitting by new line when reading the file lines
            # ignores new lines at the ends of files
            # We also remove leading new lines, since there is after a new line after an annotation
            new_file_contents = "#{new_lines.join("\n")}\n".gsub(/\A\n+/, '')
            filepath.write(new_file_contents)
          end
        end

        sig { override.returns(String) }
        def description
          DESCRIPTION
        end

        sig { override.void }
        def bust_caches!
          @@map_files_to_owners = {} # rubocop:disable Style/ClassVars
        end
      end
    end
  end
end
