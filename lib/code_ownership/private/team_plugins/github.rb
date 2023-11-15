# typed: true

module CodeOwnership
  module Private
    module TeamPlugins
      class Github < CodeTeams::Plugin
        extend T::Sig
        extend T::Helpers

        GithubStruct = Struct.new(:team, :do_not_add_to_codeowners_file)

        sig { returns(GithubStruct) }
        def github
          raw_github = @team.raw_hash['github'] || {}

          GithubStruct.new(
            raw_github['team'],
            raw_github['do_not_add_to_codeowners_file'] || false
          )
        end

        sig { override.params(teams: T::Array[CodeTeams::Team]).returns(T::Array[String]) }
        def self.validation_errors(teams)
          all_github_teams = teams.flat_map { |team| self.for(team).github.team }
          missing_github_teams = teams.select { |team| self.for(team).github.team.nil? }

          teams_used_more_than_once = all_github_teams.tally.select do |_team, count|
            count > 1
          end

          errors = T.let([], T::Array[String])

          if missing_github_teams.any?
            errors << <<~ERROR
              The following teams are missing `github.team` entries

              #{missing_github_teams.map(&:config_yml).join("\n")}
            ERROR
          end

          if teams_used_more_than_once.any?
            errors << <<~ERROR
              The following teams are specified multiple times:
              Each code team must have a unique GitHub team in order to write the CODEOWNERS file correctly.

              #{teams_used_more_than_once.keys.join("\n")}
            ERROR
          end

          errors
        end
      end
    end
  end
end
