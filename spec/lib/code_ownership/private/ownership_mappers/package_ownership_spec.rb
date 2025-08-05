RSpec.describe CodeOwnership::Private::OwnershipMappers::PackageOwnership do
  before do
    write_configuration
    write_file('config/teams/bar.yml', <<~CONTENTS)
      name: Bar
    CONTENTS

    write_file('packs/my_other_package/package.yml', <<~CONTENTS)
      enforce_dependency: true
      enforce_privacy: true
      owner: Bar
    CONTENTS

    write_file('packs/my_other_package/my_file.rb')

    write_file('package.yml', <<~CONTENTS)
      enforce_dependency: true
      enforce_privacy: true
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

        ## Owner in .codeowner
        This team owns nothing in this category.

        ## Owner metadata key in package.yml
        - packs/my_other_package/**/**

        ## Owner metadata key in package.json
        This team owns nothing in this category.

        ## Team YML ownership
        - config/teams/bar.yml
      OWNERSHIP
    end
  end

  describe 'CodeOwnership.for_file' do
    it 'can find the owner of files in team-owned pack' do
      expect(CodeOwnership.for_file('packs/my_other_package/my_file.rb').name).to eq 'Bar'
    end
  end

  describe 'CodeOwnership.for_package' do
    it 'returns the right team' do
      team = CodeOwnership.for_package(Packs.find('packs/my_other_package'))
      expect(team.name).to eq 'Bar'
    end
  end
end
