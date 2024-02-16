# typed: strict
# frozen_string_literal: true

module CodeOwnership
  module Private
    class OwnerAssigner
      extend T::Sig

      sig { params(globs_to_owning_team_map: GlobsToOwningTeamMap).returns(GlobsToOwningTeamMap) }
      def self.assign_owners(globs_to_owning_team_map)
        globs_to_owning_team_map.each_with_object({}) do |(glob, owner), mapping|
          mapping[glob] = owner if File.exist?(glob)
          Dir.glob(glob).each do |file|
            mapping[file] ||= owner
          end
        end
      end
    end
  end
end
