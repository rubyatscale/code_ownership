# frozen_string_literal: true

# typed: strict

module CodeOwnership
  module Private
    module TeamFinder
      module_function

      extend T::Sig
      extend T::Helpers

      requires_ancestor { Kernel }

      sig { params(file_path: String, allow_raise: T::Boolean).returns(T.nilable(CodeTeams::Team)) }
      def for_file(file_path, allow_raise: false)
        return nil if file_path.start_with?('./')

        return FilePathTeamCache.get(file_path) if FilePathTeamCache.cached?(file_path)

        result = T.let(RustCodeOwners.for_file(file_path), T.nilable(T::Hash[Symbol, String]))
        return if result.nil?

        if result[:team_name].nil?
          FilePathTeamCache.set(file_path, nil)
        else
          FilePathTeamCache.set(file_path, T.let(find_team!(T.must(result[:team_name]), allow_raise: allow_raise), T.nilable(CodeTeams::Team)))
        end

        FilePathTeamCache.get(file_path)
      end

      sig { params(files: T::Array[String], allow_raise: T::Boolean).returns(T::Hash[String, T.nilable(CodeTeams::Team)]) }
      def teams_for_files(files, allow_raise: false)
        result = {}

        # Collect cached results and identify non-cached files
        not_cached_files = []
        files.each do |file_path|
          if FilePathTeamCache.cached?(file_path)
            result[file_path] = FilePathTeamCache.get(file_path)
          else
            not_cached_files << file_path
          end
        end

        return result if not_cached_files.empty?

        # Process non-cached files
        ::RustCodeOwners.teams_for_files(not_cached_files).each do |path_team|
          file_path, team = path_team
          found_team = team ? find_team!(team[:team_name], allow_raise: allow_raise) : nil
          FilePathTeamCache.set(file_path, found_team)
          result[file_path] = found_team
        end

        result
      end

      sig { params(klass: T.nilable(T.any(T::Class[T.anything], T::Module[T.anything]))).returns(T.nilable(::CodeTeams::Team)) }
      def for_class(klass)
        file_path = FilePathFinder.path_from_klass(klass)
        return nil if file_path.nil?

        for_file(file_path)
      end

      sig { params(package: Packs::Pack).returns(T.nilable(::CodeTeams::Team)) }
      def for_package(package)
        owner_name = package.raw_hash['owner'] || package.metadata['owner']
        return nil if owner_name.nil?

        find_team!(owner_name, allow_raise: true)
      end

      sig { params(backtrace: T.nilable(T::Array[String]), excluded_teams: T::Array[::CodeTeams::Team]).returns(T.nilable(::CodeTeams::Team)) }
      def for_backtrace(backtrace, excluded_teams: [])
        first_owned_file_for_backtrace(backtrace, excluded_teams: excluded_teams)&.first
      end

      sig { params(backtrace: T.nilable(T::Array[String]), excluded_teams: T::Array[::CodeTeams::Team]).returns(T.nilable([::CodeTeams::Team, String])) }
      def first_owned_file_for_backtrace(backtrace, excluded_teams: [])
        FilePathFinder.from_backtrace(backtrace).each do |file|
          team = for_file(file)
          if team && !excluded_teams.include?(team)
            return [team, file]
          end
        end

        nil
      end

      sig { params(team_name: String, allow_raise: T::Boolean).returns(T.nilable(CodeTeams::Team)) }
      def find_team!(team_name, allow_raise: false)
        team = CodeTeams.find(team_name)
        if team.nil? && allow_raise
          raise(StandardError, "Could not find team with name: `#{team_name}`. Make sure the team is one of `#{CodeTeams.all.map(&:name).sort}`")
        end

        team
      end

      private_class_method(:find_team!)
    end
  end
end
