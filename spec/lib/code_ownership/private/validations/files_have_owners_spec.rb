module CodeOwnership
  RSpec.describe Private::Validations::FilesHaveOwners do
    describe 'CodeOwnership.validate!' do
      let(:codeowners_validation) { Private::Validations::GithubCodeownersUpToDate }

      context 'input files are not part of configured owned_globs' do
        before do
          write_file('Gemfile', '')

          write_configuration
        end

        it 'does not raise an error' do
          expect { CodeOwnership.validate!(files: ['Gemfile']) }.to_not raise_error
        end
      end

      context 'a file in owned_globs does not have an owner' do
        before do
          write_file('app/missing_ownership.rb', '')

          write_file('app/some_other_file.rb', <<~CONTENTS)
            # @team Bar
          CONTENTS

          write_file('config/teams/bar.yml', <<~CONTENTS)
            name: Bar
          CONTENTS
        end

        context 'the file is not in unowned_globs' do
          before do
            write_configuration
          end

          it 'lets the user know the file must have ownership' do
            expect { CodeOwnership.validate! }.to raise_error do |e|
              expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
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
            write_configuration('unowned_globs' => ['app/missing_ownership.rb', 'config/code_ownership.yml'])
          end

          it 'does not raise an error' do
            expect { CodeOwnership.validate! }.to_not raise_error
          end
        end
      end

      context 'many files in owned_globs do not have an owner' do
        before do
          write_configuration

          500.times do |i|
            write_file("app/missing_ownership#{i}.rb", '')
          end
        end

        it 'lets the user know the file must have ownership' do
          expect { CodeOwnership.validate! }.to raise_error do |e|
            expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
            expect(e.message).to include 'Some files are missing ownership:'
            500.times do |i|
              expect(e.message).to include "- app/missing_ownership#{i}.rb"
            end
          end
        end
      end
    end
  end
end
