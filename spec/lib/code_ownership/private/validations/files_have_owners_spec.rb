module CodeOwnership
  RSpec.describe Private::Validations::FilesHaveOwners do
    describe 'CodeOwnership.validate!' do
      let(:codeowners_validation) { Private::Validations::GithubCodeownersUpToDate }

      context 'input files are not part of configured owned_globs' do
        before do
          write_file('Gemfile', <<~CONTENTS)
          CONTENTS

          create_minimal_configuration
        end

        it 'does not raise an error' do
          expect { CodeOwnership.validate!(files: ['Gemfile']) }.to_not raise_error
        end
      end

      context 'a file in owned_globs does not have an owner' do
        before do
          write_file('app/missing_ownership.rb', <<~CONTENTS)
          CONTENTS
        end

        context 'the file is not in unowned_globs' do
          before do
            create_minimal_configuration
          end

          it 'lets the user know the file must have ownership' do
            expect { CodeOwnership.validate! }.to raise_error do |e|
              expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
              puts e.message
              expect(e.message).to eq <<~EXPECTED.chomp
                Some files are missing ownership:

                - app/missing_ownership.rb

                See https://github.com/rubyatscale/code_ownership#README.md for more details
              EXPECTED
            end
          end

          context 'the input files do not include the file missing ownership' do
            it 'ignores the file missing ownership' do
              expect { CodeOwnership.validate!(files: ['app/some_other_file.rb']) }.to_not raise_error
            end
          end
        end

        context 'that file is in unowned_globs' do
          before do
            write_file('config/code_ownership.yml', <<~YML)
              owned_globs:
                - 'app/**/*.rb'
              unowned_globs:
                - app/missing_ownership.rb
            YML
          end

          it 'does not raise an error' do
            expect { CodeOwnership.validate! }.to_not raise_error
          end
        end
      end

    end
  end
end
