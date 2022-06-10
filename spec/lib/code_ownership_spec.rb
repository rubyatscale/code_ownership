RSpec.describe CodeOwnership do
  describe '.validate!' do
    let(:codeowners_validation) { CodeOwnership.const_get(:Private)::Validations::GithubCodeownersUpToDate }

    describe 'files are required to have ownership validation' do
      context 'input files are not part of configured owned_globs' do
        before do
          write_file('Gemfile', <<~CONTENTS)
          CONTENTS

          create_minimal_configuration
        end

        it 'raises errors due to being misconfigured' do
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

                See https://github.com/bigrails/code_ownership#README.md for more details
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

          it 'lets the user know the file must have ownership' do
            expect { CodeOwnership.validate! }.to_not raise_error
          end
        end
      end
    end

    describe 'files can only be mapped in one way validation' do
      context 'a file in owned_globs has ownership defined in multiple ways' do
        before do
          write_file('config/code_ownership.yml', <<~YML)
            owned_globs:
              - '{app,components,config,frontend,lib,packs,spec}/**/*.{rb,rake,js,jsx,ts,tsx}'
          YML

          write_file('packs/my_pack/owned_file.rb', <<~CONTENTS)
            # @team Bar
          CONTENTS

          write_file('frontend/javascripts/packages/my_package/owned_file.jsx', <<~CONTENTS)
            // @team Bar
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
              - packs/**
              - frontend/javascripts/packages//**
          CONTENTS

          write_file('packs/my_pack/package.yml', <<~CONTENTS)
            enforce_dependency: true
            enforce_privacy: true
            metadata:
              owner: Bar
          CONTENTS
        end

        it 'lets the user know that each file can only have ownership defined in one way' do
          expect(CodeOwnership.for_file('app/missing_ownership.rb')).to eq nil

          expect { CodeOwnership.validate! }.to raise_error do |e|
            expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
            puts e.message
            expect(e.message).to eq <<~EXPECTED.chomp
              Code ownership should only be defined for each file in one way. The following files have declared ownership in multiple ways.

              - frontend/javascripts/packages/my_package/owned_file.jsx (Annotations at the top of file, Owner metadata key in package.json)
              - packs/my_pack/owned_file.rb (Annotations at the top of file, Owner metadata key in package.yml)

              See https://github.com/bigrails/code_ownership#README.md for more details
            EXPECTED
          end
        end

        context 'the input files do not include the file owned in multiple ways' do
          it 'ignores the file with multiple ownership' do
            expect { CodeOwnership.validate!(files: ['app/some_other_file.rb']) }.to_not raise_error
          end
        end
      end
    end

    describe '.github/CODEOWNERS validation' do
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
                CODEOWNERS out of date. Ensure pre-commit hook is set up correctly and used. You can also run bin/codeownership validate to update the CODEOWNERS file

                See https://github.com/bigrails/code_ownership#README.md for more details
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
                CODEOWNERS out of date. Ensure pre-commit hook is set up correctly and used. You can also run bin/codeownership validate to update the CODEOWNERS file

                See https://github.com/bigrails/code_ownership#README.md for more details
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
                  CODEOWNERS out of date. Ensure pre-commit hook is set up correctly and used. You can also run bin/codeownership validate to update the CODEOWNERS file

                  See https://github.com/bigrails/code_ownership#README.md for more details
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
                  CODEOWNERS out of date. Ensure pre-commit hook is set up correctly and used. You can also run bin/codeownership validate to update the CODEOWNERS file

                  See https://github.com/bigrails/code_ownership#README.md for more details
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
            CODEOWNERS

            expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate!(autocorrect: false) }.to raise_error do |e|
              expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
              puts e.message
              expect(e.message).to eq <<~EXPECTED.chomp
                CODEOWNERS out of date. Ensure pre-commit hook is set up correctly and used. You can also run bin/codeownership validate to update the CODEOWNERS file

                CODEOWNERS should contain the following lines, but does not:
                - ""
                - "/packs/my_pack/owned_file.rb @MyOrg/bar-team"
                - "# Owner metadata key in package.yml"
                - "/packs/my_other_package/**/** @MyOrg/bar-team"
                - ""

                CODEOWNERS should not contain the following lines, but it does:
                - "/frontend/some/extra/line/that/should/not/exist @MyOrg/bar-team"
                - "# Some extra comment that should not be here"

                See https://github.com/bigrails/code_ownership#README.md for more details
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

            CODEOWNERS

            expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate!(autocorrect: false) }.to raise_error do |e|
              expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
              puts e.message
              expect(e.message).to eq <<~EXPECTED.chomp
                CODEOWNERS out of date. Ensure pre-commit hook is set up correctly and used. You can also run bin/codeownership validate to update the CODEOWNERS file

                CODEOWNERS should not contain the following lines, but it does:
                - "/frontend/some/extra/line/that/should/not/exist @MyOrg/bar-team"
                - "# Some extra comment that should not be here"

                See https://github.com/bigrails/code_ownership#README.md for more details
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

            CODEOWNERS

            expect_any_instance_of(codeowners_validation).to_not receive(:`) # rubocop:disable RSpec/AnyInstance
            expect { CodeOwnership.validate!(autocorrect: false) }.to raise_error do |e|
              expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
              puts e.message
              expect(e.message).to eq <<~EXPECTED.chomp
                CODEOWNERS out of date. Ensure pre-commit hook is set up correctly and used. You can also run bin/codeownership validate to update the CODEOWNERS file

                CODEOWNERS should contain the following lines, but does not:
                - ""
                - "/packs/my_pack/owned_file.rb @MyOrg/bar-team"
                - "# Owner metadata key in package.yml"
                - "/packs/my_other_package/**/** @MyOrg/bar-team"
                - ""

                See https://github.com/bigrails/code_ownership#README.md for more details
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

    describe 'teams must exist validation' do
      before do
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS

        create_minimal_configuration
      end

      context 'invalid team in a file annotation' do
        before do
          write_file('app/some_file.rb', <<~CONTENTS)
            # @team Foo
          CONTENTS
        end

        it 'lets the user know the team cannot be found in the file' do
          expect { CodeOwnership.validate! }.to raise_error do |e|
            expect(e).to be_a StandardError
            puts e.message
            expect(e.message).to eq <<~EXPECTED.chomp
              Could not find team with name: `Foo` in app/some_file.rb. Make sure the team is one of `["Bar"]`
            EXPECTED
          end
        end
      end

      context 'invalid team in a package.yml' do
        before do
          write_file('packs/my_pack/package.yml', <<~CONTENTS)
            metadata:
              owner: Foo
          CONTENTS
        end

        it 'lets the user know the team cannot be found in the package.yml' do
          expect { CodeOwnership.validate! }.to raise_error do |e|
            expect(e).to be_a StandardError
            puts e.message
            expect(e.message).to eq <<~EXPECTED.chomp
              Could not find team with name: `Foo` in packs/my_pack/package.yml. Make sure the team is one of `["Bar"]`
            EXPECTED
          end
        end
      end

      context 'invalid team in a package.json' do
        before do
          write_file('frontend/javascripts/my_package/package.json', <<~CONTENTS)
            {
              "metadata": {
                "owner": "Foo"
              }
            }
          CONTENTS
        end

        it 'lets the user know the team cannot be found in the package.json' do
          expect { CodeOwnership.validate! }.to raise_error do |e|
            expect(e).to be_a StandardError
            puts e.message
            expect(e.message).to eq <<~EXPECTED.chomp
              Could not find team with name: `Foo` in frontend/javascripts/my_package. Make sure the team is one of `["Bar"]`
            EXPECTED
          end
        end
      end
    end
  end

  describe '.for_file' do
    before { create_non_empty_application }

    it 'can find the owner of a ruby file with file annotations' do
      expect(CodeOwnership.for_file('packs/my_pack/owned_file.rb')).to eq Teams.find('Bar')
    end

    it 'can find the owner of a javascript file with file annotations' do
      expect(CodeOwnership.for_file('frontend/javascripts/packages/my_package/owned_file.jsx')).to eq Teams.find('Bar')
    end

    it 'can find the owner of ruby files in owned_globs' do
      expect(CodeOwnership.for_file('app/services/bar_stuff/thing.rb')).to eq Teams.find('Bar')
    end

    it 'can find the owner of javascript files in owned_globs' do
      expect(CodeOwnership.for_file('frontend/javascripts/bar_stuff/thing.jsx')).to eq Teams.find('Bar')
    end

    it 'can find the owner of files in team-owned packwerk packages' do
      expect(CodeOwnership.for_file('packs/my_other_package/my_file.rb')).to eq Teams.find('Bar')
    end

    it 'can find the owner of files in team-owned javascript packages' do
      expect(CodeOwnership.for_file('frontend/javascripts/packages/my_other_package/my_file.jsx')).to eq Teams.find('Bar')
    end

    describe 'path formatting expectations' do
      # All file paths must be clean paths relative to the root: https://apidock.com/ruby/Pathname/cleanpath
      it 'will not find the ownership of a file that is not a cleanpath' do
        expect(CodeOwnership.for_file('./packs/my_pack/owned_file.rb')).to eq nil
        expect(CodeOwnership.for_file('./frontend/javascripts/packages/my_package/owned_file.jsx')).to eq nil
        expect(CodeOwnership.for_file('./app/services/bar_stuff/thing.rb')).to eq nil
        expect(CodeOwnership.for_file('./frontend/javascripts/bar_stuff/thing.jsx')).to eq nil
        expect(CodeOwnership.for_file('./packs/my_other_package/my_file.rb')).to eq nil
        expect(CodeOwnership.for_file('./frontend/javascripts/packages/my_other_package/my_file.jsx')).to eq nil
      end
    end
  end

  describe '.for_backtrace' do
    def prevent_false_positive!
      # The above code should raise, and we should never arrive at this next expectation.
      # This is just to protect against a case where we have a false-postive test because the above does not raise.
      expect(true).to eq false # rubocop:disable RSpec/ExpectActual
    end

    before do
      create_files_with_defined_classe
    end

    context 'excluded_teams is not passed in as an input parameter' do
      it 'finds the right team' do
        begin # rubocop:disable Style/RedundantBegin
          MyFile.raise_error
          prevent_false_positive!
        rescue StandardError => ex
          expect(CodeOwnership.for_backtrace(ex.backtrace)).to eq Teams.find('Bar')
        end
      end
    end

    context 'excluded_teams is passed in as an input parameter' do
      it 'ignores the first part of the stack trace and finds the next viable owner' do
        begin # rubocop:disable Style/RedundantBegin
          MyFile.raise_error
          prevent_false_positive!
        rescue StandardError => ex
          team_to_exclude = Teams.find('Bar')
          expect(CodeOwnership.for_backtrace(ex.backtrace, excluded_teams: [team_to_exclude])).to eq Teams.find('Foo')
        end
      end
    end
  end

  describe '.for_class' do
    before { create_files_with_defined_classe }

    it 'can find the right owner for a class' do
      expect(CodeOwnership.for_class(MyFile)).to eq Teams.find('Foo')
    end

    it 'memoizes the values' do
      expect(CodeOwnership.for_class(MyFile)).to eq Teams.find('Foo')
      allow(CodeOwnership).to receive(:for_file)
      allow(Object).to receive(:const_source_location)
      expect(CodeOwnership.for_class(MyFile)).to eq Teams.find('Foo')

      # Memoization should avoid these calls
      expect(CodeOwnership).to_not have_received(:for_file)
      expect(Object).to_not have_received(:const_source_location)
    end
  end

  describe '.for_package' do
    before { create_non_empty_application }

    it 'returns the right team' do
      team = CodeOwnership.for_package(ParsePackwerk.all.last)
      expect(team.name).to eq 'Bar'
    end
  end

  describe '.remove_file_annotation!' do
    subject(:remove_file_annotation) do
      CodeOwnership.remove_file_annotation!(filename)
      # Getting the owner gets stored in the cache, so after we remove the file annotation we want to bust the cache
      CodeOwnership.bust_caches!
    end

    before do
      write_file('config/teams/foo.yml', <<~CONTENTS)
        name: Foo
      CONTENTS
    end

    context 'ruby file has no annotation' do
      let(:filename) { 'app/my_file.rb' }

      before do
        write_file(filename, <<~CONTENTS)
          # Empty file
        CONTENTS
      end

      it 'has no effect' do
        expect(File.read(filename)).to eq "# Empty file\n"

        remove_file_annotation

        expect(File.read(filename)).to eq "# Empty file\n"
      end
    end

    context 'ruby file has annotation' do
      let(:filename) { 'app/my_file.rb' }

      before do
        write_file(filename, <<~CONTENTS)
          # @team Foo

          # Some content
        CONTENTS
      end

      it 'removes the annotation' do
        current_ownership = CodeOwnership.for_file(filename)
        expect(current_ownership&.name).to eq 'Foo'
        expect(File.read(filename)).to eq <<~RUBY
          # @team Foo

          # Some content
        RUBY

        remove_file_annotation

        new_ownership = CodeOwnership.for_file(filename)
        expect(new_ownership).to eq nil
        expected_output = <<~RUBY
          # Some content
        RUBY

        expect(File.read(filename)).to eq expected_output
      end
    end

    context 'javascript file has annotation' do
      let(:filename) { 'app/my_file.jsx' }

      before do
        write_file(filename, <<~CONTENTS)
          // @team Foo

          // Some content
        CONTENTS
      end

      it 'removes the annotation' do
        current_ownership = CodeOwnership.for_file(filename)
        expect(current_ownership&.name).to eq 'Foo'
        expect(File.read(filename)).to eq <<~JAVASCRIPT
          // @team Foo

          // Some content
        JAVASCRIPT

        remove_file_annotation

        new_ownership = CodeOwnership.for_file(filename)
        expect(new_ownership).to eq nil
        expected_output = <<~JAVASCRIPT
          // Some content
        JAVASCRIPT

        expect(File.read(filename)).to eq expected_output
      end
    end

    context 'file has new lines after the annotation' do
      let(:filename) { 'app/my_file.rb' }

      before do
        write_file(filename, <<~CONTENTS)
          # @team Foo


          # Some content


          # Some other content
        CONTENTS
      end

      it 'removes the annotation and the leading new lines' do
        expect(File.read(filename)).to eq <<~RUBY
          # @team Foo


          # Some content


          # Some other content
        RUBY

        remove_file_annotation

        expected_output = <<~RUBY
          # Some content


          # Some other content
        RUBY

        expect(File.read(filename)).to eq expected_output
      end
    end
  end
end
