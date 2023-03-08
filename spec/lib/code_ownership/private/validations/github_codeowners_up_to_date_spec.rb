module CodeOwnership
  RSpec.describe Private::Validations::GithubCodeownersUpToDate do
    describe 'CodeOwnership.validate!' do
      let(:codeowners_validation) { Private::Validations::GithubCodeownersUpToDate }

      context 'run with autocorrect' do
        before do
          create_minimal_configuration
        end

        context 'in an empty application' do
          it 'automatically regenerates the codeowners file' do
            expect(Pathname.new('.github/CODEOWNERS')).to_not exist
            expect_any_instance_of(codeowners_validation).to receive(:`).with("git add #{Pathname.pwd.join('.github/CODEOWNERS')}") # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate! }.to_not raise_error
            expect(Pathname.new('.github/CODEOWNERS').read).to eq <<~EXPECTED
              # STOP! - DO NOT EDIT THIS FILE MANUALLY
              # This file was automatically generated by "bin/codeownership validate".
              #
              # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
              # teams. This is useful when developers create Pull Requests since the
              # code/file owner is notified. Reference GitHub docs for more details:
              # https://help.github.com/en/articles/about-code-owners

            EXPECTED
          end
        end

        context 'in an non-empty application' do
          before { create_non_empty_application }

          it 'automatically regenerates the codeowners file' do
            expect(Pathname.new('.github/CODEOWNERS')).to_not exist
            expect_any_instance_of(codeowners_validation).to receive(:`).with("git add #{Pathname.pwd.join('.github/CODEOWNERS')}") # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate! }.to_not raise_error
            expect(Pathname.new('.github/CODEOWNERS').read).to eq <<~EXPECTED
              # STOP! - DO NOT EDIT THIS FILE MANUALLY
              # This file was automatically generated by "bin/codeownership validate".
              #
              # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
              # teams. This is useful when developers create Pull Requests since the
              # code/file owner is notified. Reference GitHub docs for more details:
              # https://help.github.com/en/articles/about-code-owners


              # Annotations at the top of file
              /frontend/javascripts/packages/my_package/owned_file.jsx @MyOrg/bar-team
              /packs/my_pack/owned_file.rb @MyOrg/bar-team

              # Team-specific owned globs
              /app/services/bar_stuff/** @MyOrg/bar-team
              /frontend/javascripts/bar_stuff/** @MyOrg/bar-team

              # Owner metadata key in package.yml
              /packs/my_other_package/**/** @MyOrg/bar-team

              # Owner metadata key in package.json
              /frontend/javascripts/packages/my_other_package/**/** @MyOrg/bar-team

              # Team YML ownership
              /config/teams/bar.yml @MyOrg/bar-team
            EXPECTED
          end

          context 'the user has passed in specific input files into the validate method' do
            it 'still automatically regenerates the codeowners file, since we look at all files when regenerating CODEOWNERS' do
              expect(Pathname.new('.github/CODEOWNERS')).to_not exist
              expect_any_instance_of(codeowners_validation).to receive(:`).with("git add #{Pathname.pwd.join('.github/CODEOWNERS')}") # rubocop:disable RSpec/AnyInstance
              expect { CodeOwnership.validate! }.to_not raise_error
              expect(Pathname.new('.github/CODEOWNERS').read).to eq <<~EXPECTED
                # STOP! - DO NOT EDIT THIS FILE MANUALLY
                # This file was automatically generated by "bin/codeownership validate".
                #
                # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
                # teams. This is useful when developers create Pull Requests since the
                # code/file owner is notified. Reference GitHub docs for more details:
                # https://help.github.com/en/articles/about-code-owners


                # Annotations at the top of file
                /frontend/javascripts/packages/my_package/owned_file.jsx @MyOrg/bar-team
                /packs/my_pack/owned_file.rb @MyOrg/bar-team

                # Team-specific owned globs
                /app/services/bar_stuff/** @MyOrg/bar-team
                /frontend/javascripts/bar_stuff/** @MyOrg/bar-team

                # Owner metadata key in package.yml
                /packs/my_other_package/**/** @MyOrg/bar-team

                # Owner metadata key in package.json
                /frontend/javascripts/packages/my_other_package/**/** @MyOrg/bar-team

                # Team YML ownership
                /config/teams/bar.yml @MyOrg/bar-team
              EXPECTED
            end
          end

          context 'team does not have a github team listed' do
            before do
              write_file('config/teams/bar.yml', <<~CONTENTS)
                name: Bar
                owned_globs:
                  - app/services/bar_stuff/**
                  - frontend/javascripts/bar_stuff/**
              CONTENTS
            end

            it 'does not include the team in the output' do
              expect(Pathname.new('.github/CODEOWNERS')).to_not exist
              expect { CodeOwnership.validate! }.to_not raise_error
              expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
              expect(Pathname.new('.github/CODEOWNERS').read).to eq <<~EXPECTED
                # STOP! - DO NOT EDIT THIS FILE MANUALLY
                # This file was automatically generated by "bin/codeownership validate".
                #
                # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
                # teams. This is useful when developers create Pull Requests since the
                # code/file owner is notified. Reference GitHub docs for more details:
                # https://help.github.com/en/articles/about-code-owners

              EXPECTED
            end
          end

          context 'team has chosen to not be added to CODEOWNERS' do
            before do
              write_file('config/teams/bar.yml', <<~CONTENTS)
                name: Bar
                github:
                  team: '@MyOrg/bar-team'
                  do_not_add_to_codeowners_file: true
                owned_globs:
                  - app/services/bar_stuff/**
                  - frontend/javascripts/bar_stuff/**
              CONTENTS
            end

            it 'does not include the team in the output' do
              expect(Pathname.new('.github/CODEOWNERS')).to_not exist
              expect { CodeOwnership.validate! }.to_not raise_error
              expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
              expect(Pathname.new('.github/CODEOWNERS').read).to eq <<~EXPECTED
                # STOP! - DO NOT EDIT THIS FILE MANUALLY
                # This file was automatically generated by "bin/codeownership validate".
                #
                # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
                # teams. This is useful when developers create Pull Requests since the
                # code/file owner is notified. Reference GitHub docs for more details:
                # https://help.github.com/en/articles/about-code-owners

              EXPECTED
            end
          end
        end

        context 'run without staging changes' do
          before do
            create_minimal_configuration
          end

          it 'does not stage the changes to the codeowners file' do
            expect(Pathname.new('.github/CODEOWNERS')).to_not exist
            expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate!(stage_changes: false) }.to_not raise_error
            expect(Pathname.new('.github/CODEOWNERS').read).to eq <<~EXPECTED
              # STOP! - DO NOT EDIT THIS FILE MANUALLY
              # This file was automatically generated by "bin/codeownership validate".
              #
              # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
              # teams. This is useful when developers create Pull Requests since the
              # code/file owner is notified. Reference GitHub docs for more details:
              # https://help.github.com/en/articles/about-code-owners

            EXPECTED
          end
        end
      end

      context 'run without autocorrect' do
        before do
          create_minimal_configuration
        end

        context 'in an empty application' do
          it 'automatically regenerates the codeowners file' do
            expect(Pathname.new('.github/CODEOWNERS')).to_not exist
            expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate!(autocorrect: false) }.to raise_error do |e|
              expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
              puts e.message
              expect(e.message).to eq <<~EXPECTED.chomp
                CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file

                See https://github.com/rubyatscale/code_ownership#README.md for more details
              EXPECTED
            end
            expect(Pathname.new('.github/CODEOWNERS')).to_not exist
          end
        end

        context 'in an non-empty application' do
          before { create_non_empty_application }

          it 'automatically regenerates the codeowners file' do
            expect(Pathname.new('.github/CODEOWNERS')).to_not exist
            expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate!(autocorrect: false) }.to raise_error do |e|
              expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
              puts e.message
              expect(e.message).to eq <<~EXPECTED.chomp
                CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file

                See https://github.com/rubyatscale/code_ownership#README.md for more details
              EXPECTED
            end
            expect(Pathname.new('.github/CODEOWNERS')).to_not exist
          end

          context 'team does not have a github team listed' do
            before do
              write_file('config/teams/bar.yml', <<~CONTENTS)
                name: Bar
                owned_globs:
                  - app/services/bar_stuff/**
                  - frontend/javascripts/bar_stuff/**
              CONTENTS
            end

            it 'does not include the team in the output' do
              expect(Pathname.new('.github/CODEOWNERS')).to_not exist
              expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
              expect { CodeOwnership.validate!(autocorrect: false) }.to raise_error do |e|
                expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
                puts e.message
                expect(e.message).to eq <<~EXPECTED.chomp
                  CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file

                  See https://github.com/rubyatscale/code_ownership#README.md for more details
                EXPECTED
              end
              expect(Pathname.new('.github/CODEOWNERS')).to_not exist
            end
          end

          context 'team has chosen to not be added to CODEOWNERS' do
            before do
              write_file('config/teams/bar.yml', <<~CONTENTS)
                name: Bar
                github:
                  team: '@MyOrg/bar-team'
                  do_not_add_to_codeowners_file: true
                owned_globs:
                  - app/services/bar_stuff/**
                  - frontend/javascripts/bar_stuff/**
              CONTENTS
            end

            it 'does not include the team in the output' do
              expect(Pathname.new('.github/CODEOWNERS')).to_not exist
              expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
              expect { CodeOwnership.validate!(autocorrect: false) }.to raise_error do |e|
                expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
                puts e.message
                expect(e.message).to eq <<~EXPECTED.chomp
                  CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file

                  See https://github.com/rubyatscale/code_ownership#README.md for more details
                EXPECTED
              end
              expect(Pathname.new('.github/CODEOWNERS')).to_not exist
            end
          end
        end

        context 'in an application with a CODEOWNERS file that is missing lines and has extra lines' do
          before { create_non_empty_application }

          it 'prints out the diff' do
            FileUtils.mkdir('.github')
            Pathname.new('.github/CODEOWNERS').write <<~CODEOWNERS
              # STOP! - DO NOT EDIT THIS FILE MANUALLY
              # This file was automatically generated by "bin/codeownership validate".
              #
              # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
              # teams. This is useful when developers create Pull Requests since the
              # code/file owner is notified. Reference GitHub docs for more details:
              # https://help.github.com/en/articles/about-code-owners


              # Annotations at the top of file
              /frontend/javascripts/packages/my_package/owned_file.jsx @MyOrg/bar-team
              /frontend/some/extra/line/that/should/not/exist @MyOrg/bar-team

              # Team-specific owned globs
              /app/services/bar_stuff/** @MyOrg/bar-team
              /frontend/javascripts/bar_stuff/** @MyOrg/bar-team

              # Some extra comment that should not be here

              # Owner metadata key in package.json
              /frontend/javascripts/packages/my_other_package/**/** @MyOrg/bar-team

              # Team YML ownership
              /config/teams/bar.yml @MyOrg/bar-team
            CODEOWNERS

            expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate!(autocorrect: false) }.to raise_error do |e|
              expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
              puts e.message
              expect(e.message).to eq <<~EXPECTED.chomp
                CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file

                CODEOWNERS should contain the following lines, but does not:
                - ""
                - "/packs/my_pack/owned_file.rb @MyOrg/bar-team"
                - "# Owner metadata key in package.yml"
                - "/packs/my_other_package/**/** @MyOrg/bar-team"
                - ""

                CODEOWNERS should not contain the following lines, but it does:
                - "/frontend/some/extra/line/that/should/not/exist @MyOrg/bar-team"
                - "# Some extra comment that should not be here"

                See https://github.com/rubyatscale/code_ownership#README.md for more details
              EXPECTED
            end
          end
        end

        context 'in an application with a CODEOWNERS file that has extra lines' do
          before { create_non_empty_application }

          it 'prints out the diff' do
            FileUtils.mkdir('.github')
            Pathname.new('.github/CODEOWNERS').write <<~CODEOWNERS
              # STOP! - DO NOT EDIT THIS FILE MANUALLY
              # This file was automatically generated by "bin/codeownership validate".
              #
              # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
              # teams. This is useful when developers create Pull Requests since the
              # code/file owner is notified. Reference GitHub docs for more details:
              # https://help.github.com/en/articles/about-code-owners


              # Annotations at the top of file
              /frontend/javascripts/packages/my_package/owned_file.jsx @MyOrg/bar-team
              /packs/my_pack/owned_file.rb @MyOrg/bar-team
              /frontend/some/extra/line/that/should/not/exist @MyOrg/bar-team

              # Team-specific owned globs
              /app/services/bar_stuff/** @MyOrg/bar-team
              /frontend/javascripts/bar_stuff/** @MyOrg/bar-team

              # Owner metadata key in package.yml
              /packs/my_other_package/**/** @MyOrg/bar-team

              # Some extra comment that should not be here

              # Owner metadata key in package.json
              /frontend/javascripts/packages/my_other_package/**/** @MyOrg/bar-team

              # Team YML ownership
              /config/teams/bar.yml @MyOrg/bar-team
            CODEOWNERS

            expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate!(autocorrect: false) }.to raise_error do |e|
              expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
              puts e.message
              expect(e.message).to eq <<~EXPECTED.chomp
                CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file

                CODEOWNERS should not contain the following lines, but it does:
                - "/frontend/some/extra/line/that/should/not/exist @MyOrg/bar-team"
                - "# Some extra comment that should not be here"

                See https://github.com/rubyatscale/code_ownership#README.md for more details
              EXPECTED
            end
          end
        end

        context 'in an application with a CODEOWNERS file that has missing lines' do
          before { create_non_empty_application }

          it 'prints out the diff' do
            FileUtils.mkdir('.github')
            Pathname.new('.github/CODEOWNERS').write <<~CODEOWNERS
              # STOP! - DO NOT EDIT THIS FILE MANUALLY
              # This file was automatically generated by "bin/codeownership validate".
              #
              # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
              # teams. This is useful when developers create Pull Requests since the
              # code/file owner is notified. Reference GitHub docs for more details:
              # https://help.github.com/en/articles/about-code-owners


              # Annotations at the top of file
              /frontend/javascripts/packages/my_package/owned_file.jsx @MyOrg/bar-team

              # Team-specific owned globs
              /app/services/bar_stuff/** @MyOrg/bar-team
              /frontend/javascripts/bar_stuff/** @MyOrg/bar-team

              # Owner metadata key in package.json
              /frontend/javascripts/packages/my_other_package/**/** @MyOrg/bar-team

              # Team YML ownership
              /config/teams/bar.yml @MyOrg/bar-team
            CODEOWNERS

            expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate!(autocorrect: false) }.to raise_error do |e|
              expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
              puts e.message
              expect(e.message).to eq <<~EXPECTED.chomp
                CODEOWNERS out of date. Run `bin/codeownership validate` to update the CODEOWNERS file

                CODEOWNERS should contain the following lines, but does not:
                - ""
                - "/packs/my_pack/owned_file.rb @MyOrg/bar-team"
                - "# Owner metadata key in package.yml"
                - "/packs/my_other_package/**/** @MyOrg/bar-team"
                - ""

                See https://github.com/rubyatscale/code_ownership#README.md for more details
              EXPECTED
            end
          end
        end
      end

      context 'code_ownership.yml has skip_codeowners_validation set' do
        before do
          write_file('config/code_ownership.yml', <<~YML)
            owned_globs:
              - app/**/*.rb
            skip_codeowners_validation: true
          YML
        end

        it 'skips validating the codeowners file' do
          expect(Pathname.new('.github/CODEOWNERS')).to_not exist
          expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
          expect { CodeOwnership.validate!(autocorrect: false) }.to_not raise_error
          expect(Pathname.new('.github/CODEOWNERS')).to_not exist
        end
      end
    end
  end
end
