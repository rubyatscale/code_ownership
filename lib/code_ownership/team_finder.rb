# frozen_string_literal: true

# typed: strict

module CodeOwnership
  module TeamFinder
    module_function

    extend T::Sig
    extend T::Helpers

    requires_ancestor { Kernel }

    sig { params(file_path: String).returns(T.nilable(CodeTeams::Team)) }
    def for_file(file_path)
      return nil if file_path.start_with?('./')

      return FilePathTeamCache.get(file_path) if FilePathTeamCache.cached?(file_path)

      result = T.let(RustCodeOwners.for_file(file_path), T.nilable(T::Hash[Symbol, String]))
      return if result.nil?

      if result[:team_name].nil?
        FilePathTeamCache.set(file_path, nil)
      else
        FilePathTeamCache.set(file_path, T.let(find_team!(T.must(result[:team_name])), T.nilable(CodeTeams::Team)))
      end

      FilePathTeamCache.get(file_path)
    end

    sig { params(klass: T.nilable(T.any(T::Class[T.anything], Module))).returns(T.nilable(::CodeTeams::Team)) }
    def for_class(klass)
      file_path = FilePathFinder.path_from_klass(klass)
      return nil if file_path.nil?

      for_file(file_path)
    end

    sig { params(package: Packs::Pack).returns(T.nilable(::CodeTeams::Team)) }
    def for_package(package)
      owner_name = package.raw_hash['owner'] || package.metadata['owner']
      return nil if owner_name.nil?

      find_team!(owner_name)
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

    sig { params(team_name: String).returns(CodeTeams::Team) }
    def find_team!(team_name)
      CodeTeams.find(team_name) ||
        raise(StandardError, "Could not find team with name: `#{team_name}`. Make sure the team is one of `#{CodeTeams.all.map(&:name).sort}`")
    end

    private_class_method(:find_team!)
  end
end
