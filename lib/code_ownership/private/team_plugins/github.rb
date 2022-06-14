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
      end
    end
  end
end
