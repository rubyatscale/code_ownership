module CodeOwnership
  RSpec.describe Private::Validations::FilesHaveUniqueOwners do
    describe 'CodeOwnership.validate!' do
      context 'a file in owned_globs has ownership defined in multiple ways' do
        before do
          write_configuration

          write_file('app/services/some_other_file.rb', <<~YML)
            # @team Bar
          YML

          write_file('packs/my_pack/owned_file.rb', <<~CONTENTS)
            # @team Bar
          CONTENTS

          write_file('frontend/javascripts/packages/my_package/owned_file.jsx', <<~CONTENTS)
            // @team Bar
          CONTENTS

          write_file('frontend/javascripts/packages/my_package/.codeowner', <<~CONTENTS)
            Bar
          CONTENTS

          write_file('frontend/javascripts/packages/my_package/package.json', <<~CONTENTS)
            {
              "name": "@gusto/my_package",
              "metadata": {
                "owner": "Bar"
              }
            }
          CONTENTS

          write_file('config/teams/bar.yml', <<~CONTENTS)
            name: Bar
            owned_globs:
              - packs/**/**
              - frontend/javascripts/packages/**/**
          CONTENTS

          write_file('packs/my_pack/package.yml', <<~CONTENTS)
            enforce_dependency: true
            enforce_privacy: true
            owner: Bar
          CONTENTS

          write_file('package.yml', <<~CONTENTS)
            enforce_dependency: true
            enforce_privacy: true
          CONTENTS
        end

        it 'lets the user know that each file can only have ownership defined in one way' do
          expect(CodeOwnership.for_file('app/missing_ownership.rb')).to eq nil
          expect { CodeOwnership.validate! }.to raise_error do |e|
            expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
            expect(e.message).to eq <<~EXPECTED.chomp
              Code ownership should only be defined for each file in one way. The following files have declared ownership in multiple ways.

              - frontend/javascripts/packages/my_package/owned_file.jsx (Annotations at the top of file, Team-specific owned globs, Owner in .codeowner, Owner metadata key in package.json)
              - frontend/javascripts/packages/my_package/package.json (Team-specific owned globs, Owner in .codeowner, Owner metadata key in package.json)
              - packs/my_pack/owned_file.rb (Annotations at the top of file, Team-specific owned globs, Owner metadata key in package.yml)
              - packs/my_pack/package.yml (Team-specific owned globs, Owner metadata key in package.yml)

              See https://github.com/rubyatscale/code_ownership#README.md for more details
            EXPECTED
          end
        end

        it "ignores the file with multiple ownership if it's not in the files param" do
          expect { CodeOwnership.validate!(files: ['app/services/some_other_file.rb']) }.to_not raise_error
        end
      end

      context 'pack has ownership and file has annotation for different team' do
        before do
          write_configuration

          write_file('config/teams/bar.yml', <<~CONTENTS)
            name: Bar
          CONTENTS

          write_file('config/teams/foo.yml', <<~CONTENTS)
            name: Foo
          CONTENTS

          write_file('packs/my_pack/special_owner_file.rb', <<~CONTENTS)
            # @team Foo
            class SpecialOwnerFile; end
          CONTENTS

          write_file('packs/my_pack/normal_owner_file.rb', <<~CONTENTS)
            class NormalOwnerFile; end
          CONTENTS

          write_file('packs/my_pack/package.yml', <<~CONTENTS)
            enforce_dependency: true
            enforce_privacy: true
            owner: Bar
          CONTENTS

          write_file('package.yml', <<~CONTENTS)
            enforce_dependency: true
            enforce_privacy: true
          CONTENTS
        end

        it 'allows file annotation to override pack ownership' do
          expect(CodeOwnership.for_file('packs/my_pack/special_owner_file.rb').name).to eq 'Foo'
          expect(CodeOwnership.for_file('packs/my_pack/normal_owner_file.rb').name).to eq 'Bar'
          expect { CodeOwnership.validate! }.to_not raise_error
        end
      end

      context 'with mutliple directory ownership files' do
        before do
          write_configuration

          write_file('config/teams/bar.yml', <<~CONTENTS)
            name: Bar
          CONTENTS

          write_file('config/teams/foo.yml', <<~CONTENTS)
            name: Foo
          CONTENTS

          write_file('app/services/exciting/some_other_file.rb', <<~YML)
            class Exciting::SomeOtherFile; end
          YML

          write_file('app/services/exciting/.codeowner', <<~YML)
            Bar
          YML

          write_file('app/services/.codeowner', <<~YML)
            Foo
          YML
        end

        it 'allows multiple .codeowner ancestor files' do
          expect(CodeOwnership.for_file('app/services/exciting/some_other_file.rb').name).to eq 'Bar'
          expect { CodeOwnership.validate! }.to_not raise_error
        end
      end
    end
  end
end
