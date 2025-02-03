# typed: strict
# frozen_string_literal: true

module CodeOwnership
  module Private
    #
    # This class is responsible for turning CodeOwnership directives (e.g. annotations, package owners)
    # into a GitHub CODEOWNERS file, as specified here:
    # https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners
    #
    class CodeownersFile
      extend T::Sig

      sig { returns(T::Array[String]) }
      def self.actual_contents_lines
        if path.exist?
          content = path.read
          lines = path.read.split("\n")
          if content.end_with?("\n")
            lines << ''
          end
          lines
        else
          ['']
        end
      end

      sig { returns(T::Array[T.nilable(String)]) }
      def self.expected_contents_lines
        cache = Private.glob_cache.raw_cache_contents

        header = <<~HEADER
          # STOP! - DO NOT EDIT THIS FILE MANUALLY
          # This file was automatically generated by "bin/codeownership validate".
          #
          # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
          # teams. This is useful when developers create Pull Requests since the
          # code/file owner is notified. Reference GitHub docs for more details:
          # https://help.github.com/en/articles/about-code-owners
        HEADER
        ignored_teams = T.let(Set.new, T::Set[String])

        github_team_map = CodeTeams.all.each_with_object({}) do |team, map|
          team_github = TeamPlugins::Github.for(team).github
          if team_github.do_not_add_to_codeowners_file
            ignored_teams << team.name
          end

          map[team.name] = team_github.team
        end

        codeowners_file_lines = T.let([], T::Array[String])

        cache.each do |mapper_description, ownership_map_cache|
          ownership_entries = []
          sorted_ownership_map_cache = ownership_map_cache.sort_by do |glob, _team|
            glob
          end
          sorted_ownership_map_cache.to_h.each do |path, code_team|
            team_mapping = github_team_map[code_team.name]
            next if team_mapping.nil?

            # Leaving a commented out entry has two major benefits:
            # 1) It allows the CODEOWNERS file to be used as a cache for validations
            # 2) It allows users to specifically see what their team will not be notified about.
            entry = if ignored_teams.include?(code_team.name)
                      "# /#{path} #{team_mapping}"
                    else
                      "/#{path} #{team_mapping}"
                    end
            ownership_entries << entry
          end

          next if ownership_entries.none?

          # When we have a special character at the beginning of a folder name, then this character
          # may be prioritized over *. However, we want the most specific folder to be listed last
          # in the CODEOWNERS file, so we should prioritize any character above an asterisk in the
          # same position.
          if mapper_description == OwnershipMappers::FileAnnotations::DESCRIPTION
            # individually owned files definitely won't have globs so we don't need to do special sorting
            sorted_ownership_entries = ownership_entries.sort
          else
            sorted_ownership_entries = ownership_entries.sort do |entry1, entry2|
              if entry2.start_with?(entry1.split('**').first)
                -1
              elsif entry1.start_with?(entry2.split('**').first)
                1
              else
                entry1 <=> entry2
              end
            end
          end

          codeowners_file_lines += ['', "# #{mapper_description}", *sorted_ownership_entries]
        end

        [
          *header.split("\n"),
          '', # For line between header and codeowners_file_lines
          *codeowners_file_lines,
          '' # For end-of-file newline
        ]
      end

      sig { void }
      def self.write!
        FileUtils.mkdir_p(path.dirname) if !path.dirname.exist?
        path.write(expected_contents_lines.join("\n"))
      end

      sig { returns(Pathname) }
      def self.path
        Pathname.pwd.join(
          CodeOwnership.configuration.codeowners_path,
          'CODEOWNERS'
        )
      end

      sig { params(files: T::Array[String]).void }
      def self.update_cache!(files)
        cache = Private.glob_cache
        # Each mapper returns a new copy of the cache subset related to that mapper,
        # which is then stored back into the cache.
        Mapper.all.each do |mapper|
          existing_cache = cache.raw_cache_contents.fetch(mapper.description, {})
          updated_cache = mapper.update_cache(existing_cache, files)
          cache.raw_cache_contents[mapper.description] = updated_cache
        end
      end

      sig { returns(T::Boolean) }
      def self.use_codeowners_cache?
        CodeownersFile.path.exist? && !Private.configuration.skip_codeowners_validation
      end

      sig { returns(GlobCache) }
      def self.to_glob_cache
        github_team_to_code_team_map = T.let({}, T::Hash[String, CodeTeams::Team])
        CodeTeams.all.each do |team|
          github_team = TeamPlugins::Github.for(team).github.team
          github_team_to_code_team_map[github_team] = team
        end
        raw_cache_contents = T.let({}, GlobCache::CacheShape)
        current_mapper = T.let(nil, T.nilable(String))
        mapper_descriptions = Set.new(Mapper.all.map(&:description))

        path.readlines.each do |line|
          line_with_no_comment = line.chomp.gsub('# ', '')
          if mapper_descriptions.include?(line_with_no_comment)
            current_mapper = line_with_no_comment
          else
            next if current_mapper.nil?
            next if line.chomp == ''

            # The codeowners file stores paths relative to the root of directory
            # Since a `/` means root of the file system from the perspective of ruby,
            # we remove that beginning slash so we can correctly glob the files out.
            normalized_line = line.gsub(/^# /, '').gsub(%r{^/}, '')
            split_line = normalized_line.split
            # Most lines will be in the format: /path/to/file my-github-team
            # This will skip over lines that are not of the correct form
            next if split_line.count > 2

            entry, github_team = split_line
            code_team = github_team_to_code_team_map[T.must(github_team)]
            # If a GitHub team is changed and a user runs `bin/codeownership validate`, we won't be able to identify
            # what team is associated with the removed github team.
            # Therefore, if we can't determine the team, we just skip it.
            # This affects how complete the cache is, but that will still be caught by `bin/codeownership validate`.
            next if code_team.nil?

            raw_cache_contents[current_mapper] ||= {}
            raw_cache_contents.fetch(current_mapper)[T.must(entry)] = github_team_to_code_team_map.fetch(T.must(github_team))
          end
        end

        GlobCache.new(raw_cache_contents)
      end
    end
  end
end
