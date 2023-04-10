module CodeOwnership
  RSpec.describe Private::OwnershipMappers::TeamYmlOwnership do
    before do
      write_configuration
      write_file('config/teams/bar.yml', <<~CONTENTS)
        name: Bar
      CONTENTS
    end

    describe 'CodeOwnership.for_team' do
      it 'prints out ownership information for the given team' do
        expect(CodeOwnership.for_team('Bar')).to eq <<~OWNERSHIP
          # Code Ownership Report for `Bar` Team
          ## Annotations at the top of file
          This team owns nothing in this category.

          ## Team-specific owned globs
          This team owns nothing in this category.

          ## Owner metadata key in package.yml
          This team owns nothing in this category.

          ## Owner metadata key in package.json
          This team owns nothing in this category.

          ## Team YML ownership
          - config/teams/bar.yml
        OWNERSHIP
      end
    end

    describe 'CodeOwnership.for_file' do
      it 'maps a team YML to be owned by the team itself' do
        expect(CodeOwnership.for_file('config/teams/bar.yml').name).to eq 'Bar'
      end
    end
  end
end
