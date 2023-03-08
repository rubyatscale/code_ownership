module CodeOwnership
  RSpec.describe Private::OwnershipMappers::FileAnnotations do
    describe '.for_team' do
      before do
        create_configuration
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS

        write_file('packs/my_pack/owned_file.rb', <<~CONTENTS)
          # @team Bar
        CONTENTS
      end

      it 'prints out ownership information for the given team' do
        expect(CodeOwnership.for_team('Bar')).to eq <<~OWNERSHIP
          # Code Ownership Report for `Bar` Team
          ## Annotations at the top of file
          - packs/my_pack/owned_file.rb

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

    describe '.for_file' do
      context 'ruby owned file' do
        before do
          create_configuration
          write_file('config/teams/bar.yml', <<~CONTENTS)
            name: Bar
          CONTENTS

          write_file('packs/my_pack/owned_file.rb', <<~CONTENTS)
            # @team Bar
          CONTENTS
        end

        it 'can find the owner of a ruby file with file annotations' do
          expect(CodeOwnership.for_file('packs/my_pack/owned_file.rb')).to eq CodeTeams.find('Bar')
        end
      end

      context 'javascript owned file' do
        before do
          create_configuration
          write_file('config/teams/bar.yml', <<~CONTENTS)
            name: Bar
          CONTENTS

          write_file('frontend/javascripts/packages/my_package/owned_file.jsx', <<~CONTENTS)
            // @team Bar
          CONTENTS
        end

        it 'can find the owner of a javascript file with file annotations' do
          expect(CodeOwnership.for_file('frontend/javascripts/packages/my_package/owned_file.jsx')).to eq CodeTeams.find('Bar')
        end
      end
    end
  end
end
