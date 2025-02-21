# typed: strict
# frozen_string_literal: true

module CodeOwnership
  module Private
    class OwnerAssigner
      extend T::Sig

      sig { params(globs_to_owning_team_map: GlobsToOwningTeamMap).returns(GlobsToOwningTeamMap) }
      def self.assign_owners(globs_to_owning_team_map)
        globs_to_owning_team_map.each_with_object({}) do |(glob, owner), mapping|
          # addresses the case where a directory name includes regex characters
          # such as `app/services/[test]/some_other_file.ts`
          mapping[glob] = owner if File.exist?(glob)
          Dir.glob(glob) do |file|
            mapping[file] ||= owner
          end
        end
      end
    end
  end
end
