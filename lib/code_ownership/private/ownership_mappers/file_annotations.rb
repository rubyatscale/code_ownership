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

        TEAM_PATTERN = T.let(%r{\A(?:#|//|-#) @team (?<team>.*)\Z}, Regexp)
        DESCRIPTION = 'Annotations at the top of file'

        sig do
          override.params(file: String)
            .returns(T.nilable(::CodeTeams::Team))
        end
        def map_file_to_owner(file)
          file_annotation_based_owner(file)
        end

        sig do
          override
            .params(files: T::Array[String])
            .returns(T::Hash[String, ::CodeTeams::Team])
        end
        def globs_to_owner(files)
          files.each_with_object({}) do |filename_relative_to_root, mapping|
            owner = file_annotation_based_owner(filename_relative_to_root)
            next unless owner

            escaped_filename = escaped_path_for_codeowners_file(filename_relative_to_root)
            mapping[escaped_filename] = owner
          end
        end

        sig do
          override.params(cache: GlobsToOwningTeamMap, files: T::Array[String]).returns(GlobsToOwningTeamMap)
        end
        def update_cache(cache, files)
          # We map files to nil owners so that files whose annotation have been removed will be properly
          # overwritten (i.e. removed) from the cache.
          fileset = Set.new(files)
          updated_cache_for_files = globs_to_owner(files)
          cache.merge!(updated_cache_for_files)

          invalid_files = cache.keys.select do |file|
            # If a file is not tracked, it should be removed from the cache
            unescaped_file = unescaped_path_for_codeowners_file(file)
            !Private.file_tracked?(unescaped_file) ||
              # If a file no longer has a file annotation (i.e. `globs_to_owner` doesn't map it)
              # it should be removed from the cache
              # We make sure to only apply this to the input files since otherwise `updated_cache_for_files.key?(file)` would always return `false` when files == []
              (fileset.include?(file) && !updated_cache_for_files.key?(file))
          end

          invalid_files.each do |invalid_file|
            cache.delete(invalid_file)
          end

          cache
        end

        sig { params(filename: String).returns(T.nilable(CodeTeams::Team)) }
        def file_annotation_based_owner(filename)
          # The annotation should be on line 1 but as of this comment
          # there's no linter installed to enforce that. We therefore check the
          # first line (the Ruby VM makes a single `read(1)` call for 8KB),
          # and if the annotation isn't in the first two lines we assume it
          # doesn't exist.

          begin
            line1 = File.foreach(filename).first
          rescue Errno::EISDIR, Errno::ENOENT
            # Ignore files that fail to read to avoid intermittent bugs.
            # Ignoring directories is needed because, e.g., Cypress screenshots
            # are saved to a folder with the test suite filename.
            return
          end

          return if !line1

          begin
            team = line1[TEAM_PATTERN, :team]
          rescue ArgumentError => e
            # rubocop:disable Gusto/NoRescueErrorMessageChecking
            if e.message.include?('invalid byte sequence')
              team = nil
            else
              raise
            end
            # rubocop:enable Gusto/NoRescueErrorMessageChecking
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
            new_lines = lines.reject { |line| line[TEAM_PATTERN] }
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
        end

        sig { params(filename: String).returns(String) }
        def escaped_path_for_codeowners_file(filename)
          # Globs can contain certain regex characters, like "[" and "]".
          # However, when we are generating a glob from a file annotation, we
          # need to escape bracket characters and interpret them literally.
          # Otherwise the resulting glob will not actually match the directory
          # containing the file.
          #
          # Example
          # filename: "/some/[xId]/myfile.tsx"
          # matches: "/some/1/file"
          # matches: "/some/2/file"
          # matches: "/some/3/file"
          # does not match!: "/some/[xId]/myfile.tsx"
          filename.gsub(/[\[\]]/) { |x| "\\#{x}" }
        end

        sig { params(filename: String).returns(String) }
        def unescaped_path_for_codeowners_file(filename)
          # Globs can contain certain regex characters, like "[" and "]".
          # We escape bracket characters and interpret them literally for
          # the CODEOWNERS file. However, we want to compare the unescaped
          # glob to the actual file path when we check if the file was deleted.
          filename.gsub(/\\([\[\]])/, '\1')
        end
      end
    end
  end
end
