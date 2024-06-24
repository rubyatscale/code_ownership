RSpec.describe CodeOwnership do
  # Look at individual validations spec to see other validaions that ship with CodeOwnership
  describe '.validate!' do
    describe 'teams must exist validation' do
      before do
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS

        write_configuration
      end

      context 'directory with [] characters' do
        before do
          write_file('app/services/.codeowner', <<~CONTENTS)
            Bar
          CONTENTS
          write_file('app/services/test/some_unowned_file.rb', '')
          write_file('app/services/[test]/some_unowned_file.rb', '')
        end

        it 'has no validation errors' do
          expect { CodeOwnership.validate!(files: ['app/services/test/some_unowned_file.rb']) }.to_not raise_error
          expect { CodeOwnership.validate!(files: ['app/services/[test]/some_unowned_file.rb']) }.to_not raise_error
        end

        context 'when the the configuration for use_git_ls_files is enabled' do
          before do
            allow(CodeOwnership.configuration).to receive(:use_git_ls_files) { true }
            allow_any_instance_of(Object).to receive(:`) do
              Pathname
                .glob(File.join('**/', '.codeowner'))
                .map(&:to_s)
                .join("\n")
            end
          end

          it 'has no validation errors' do
            expect { CodeOwnership.validate!(files: ['app/services/test/some_unowned_file.rb']) }.to_not raise_error
            expect { CodeOwnership.validate!(files: ['app/services/[test]/some_unowned_file.rb']) }.to_not raise_error
          end
        end
      end

      context 'file ownership with [] characters' do
        before do
          write_file('app/services/[test]/some_other_file.ts', <<~YML)
          // @team Bar
          // Countries
          YML

          100.times do |i|
            write_file("app/services/withoutbracket/some_other_file#{i}.ts", <<~YML)
              // @team Bar
            YML
          end
        end

        it 'has no validation errors' do
          expect { CodeOwnership.validate!(files: ['app/services/withoutbracket/some_other_file.rb']) }.to_not raise_error
          expect { CodeOwnership.validate!(files: ['app/services/[test]/some_other_file.rb']) }.to_not raise_error
          expect { CodeOwnership.validate!(files: ['app/services/*/some_other_file.rb']) }.to_not raise_error
          expect { CodeOwnership.validate!(files: ['app/*/[test]/some_other_file.rb']) }.to_not raise_error
          expect { CodeOwnership.validate! }.to_not raise_error
        end
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
            expect(e.message).to eq <<~EXPECTED.chomp
              Could not find team with name: `Foo` in app/some_file.rb. Make sure the team is one of `["Bar"]`
            EXPECTED
          end
        end
      end

      context 'invalid team in a package.yml' do
        before do
          write_file('packs/my_pack/package.yml', <<~CONTENTS)
            owner: Foo
          CONTENTS
        end

        it 'lets the user know the team cannot be found in the package.yml' do
          expect { CodeOwnership.validate! }.to raise_error do |e|
            expect(e).to be_a StandardError
            expect(e.message).to eq <<~EXPECTED.chomp
              Could not find team with name: `Foo` in packs/my_pack/package.yml. Make sure the team is one of `["Bar"]`
            EXPECTED
          end
        end
      end

      context 'invalid team in a package.yml using metadata' do
        before do
          write_file('packs/my_pack/package.yml', <<~CONTENTS)
            metadata:
              owner: Foo
          CONTENTS
        end

        it 'lets the user know the team cannot be found in the package.yml' do
          expect { CodeOwnership.validate! }.to raise_error do |e|
            expect(e).to be_a StandardError
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
            expect(e.message).to eq <<~EXPECTED.chomp
              Could not find team with name: `Foo` in frontend/javascripts/my_package. Make sure the team is one of `["Bar"]`
            EXPECTED
          end
        end
      end
    end

    context 'file is unowned' do
      before do
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS

        write_configuration

        write_file('app/services/autogenerated_code/some_unowned_file.rb', '')
      end

      it 'has no validation errors' do
        expect { CodeOwnership.validate!(files: ['app/services/autogenerated_code/some_unowned_file.rb']) }.to raise_error do |e|
          expect(e.message).to eq <<~MSG.chomp
            Some files are missing ownership:

            - app/services/autogenerated_code/some_unowned_file.rb

            See https://github.com/rubyatscale/code_ownership#README.md for more details
          MSG
        end
      end

      context 'ignored file passed in that is ignored' do
        before do
          write_configuration('unowned_globs' => ['app/services/autogenerated_code/**/**', 'vendor/bundle/**/**'])
        end

        it 'has no validation errors' do
          expect { CodeOwnership.validate!(files: ['app/services/autogenerated_code/some_unowned_file.rb']) }.to_not raise_error
        end
      end
    end
  end

  # See tests for individual ownership_mappers to understand behavior for each mapper
  describe '.for_file' do
    describe 'path formatting expectations' do
      # All file paths must be clean paths relative to the root: https://apidock.com/ruby/Pathname/cleanpath
      it 'will not find the ownership of a file that is not a cleanpath' do
        expect(CodeOwnership.for_file('packs/my_pack/owned_file.rb')).to eq CodeTeams.find('Bar')
        expect(CodeOwnership.for_file('./packs/my_pack/owned_file.rb')).to eq nil
      end
    end

    before { create_non_empty_application }

  end

  describe '.for_backtrace' do
    before do
      create_files_with_defined_classes
      write_configuration
    end

    context 'excluded_teams is not passed in as an input parameter' do
      it 'finds the right team' do
        expect { MyFile.raise_error }.to raise_error do |ex|
          expect(CodeOwnership.for_backtrace(ex.backtrace)).to eq CodeTeams.find('Bar')
        end
      end
    end

    context 'excluded_teams is passed in as an input parameter' do
      it 'ignores the first part of the stack trace and finds the next viable owner' do
        expect { MyFile.raise_error }.to raise_error do |ex|
          team_to_exclude = CodeTeams.find('Bar')
          expect(CodeOwnership.for_backtrace(ex.backtrace, excluded_teams: [team_to_exclude])).to eq CodeTeams.find('Foo')
        end
      end
    end
  end

  describe '.first_owned_file_for_backtrace' do
    before do
      write_configuration
      create_files_with_defined_classes
    end


    context 'excluded_teams is not passed in as an input parameter' do
      it 'finds the right team' do
        expect { MyFile.raise_error }.to raise_error do |ex|
          expect(CodeOwnership.first_owned_file_for_backtrace(ex.backtrace)).to eq [CodeTeams.find('Bar'), 'app/my_error.rb']
        end
      end
    end

    context 'excluded_teams is not passed in as an input parameter' do
      it 'finds the right team' do
        expect { MyFile.raise_error }.to raise_error do |ex|
          team_to_exclude = CodeTeams.find('Bar')
          expect(CodeOwnership.first_owned_file_for_backtrace(ex.backtrace, excluded_teams: [team_to_exclude])).to eq [CodeTeams.find('Foo'), 'app/my_file.rb']
        end
      end
    end

    context 'when nothing is owned' do
      it 'returns nil' do
        expect { raise 'opsy' }.to raise_error do |ex|
          expect(CodeOwnership.first_owned_file_for_backtrace(ex.backtrace)).to be_nil
        end
      end
    end
  end

  describe '.for_class' do
    before do
      create_files_with_defined_classes
      write_configuration
    end

    it 'can find the right owner for a class' do
      expect(CodeOwnership.for_class(MyFile)).to eq CodeTeams.find('Foo')
    end

    it 'memoizes the values' do
      expect(CodeOwnership.for_class(MyFile)).to eq CodeTeams.find('Foo')
      allow(CodeOwnership).to receive(:for_file)
      allow(Object).to receive(:const_source_location)
      expect(CodeOwnership.for_class(MyFile)).to eq CodeTeams.find('Foo')

      # Memoization should avoid these calls
      expect(CodeOwnership).to_not have_received(:for_file)
      expect(Object).to_not have_received(:const_source_location)
    end

    it 'returns nil if the class constant cannot be found' do
      allow(CodeOwnership).to receive(:for_file)
      allow(Object).to receive(:const_source_location).and_raise(NameError)
      expect(CodeOwnership.for_class(MyFile)).to eq nil
    end
  end

  describe '.for_team' do
    before { create_non_empty_application }

    it 'prints out ownership information for the given team' do
      expect(CodeOwnership.for_team('Bar')).to eq <<~OWNERSHIP
        # Code Ownership Report for `Bar` Team
        ## Annotations at the top of file
        - frontend/javascripts/packages/my_package/owned_file.jsx
        - packs/my_pack/owned_file.rb

        ## Team-specific owned globs
        - app/services/bar_stuff/**
        - frontend/javascripts/bar_stuff/**

        ## Owner in .codeowner
        - directory/owner/**/**

        ## Owner metadata key in package.yml
        - packs/my_other_package/**/**

        ## Owner metadata key in package.json
        - frontend/javascripts/packages/my_other_package/**/**

        ## Team YML ownership
        - config/teams/bar.yml
      OWNERSHIP
    end
  end

  describe 'pack level ownership' do
    # These errors show up from `bin/packwerk validate`, so using the `ApplicationValidator` to test
    let(:validation_result) do
      configuration = Packwerk::Configuration.from_path
      package_set = Packwerk::PackageSet.load_all_from(
        configuration.root_path,
        package_pathspec: configuration.package_paths
      )
      Packwerk.const_get(:ApplicationValidator).new.call(package_set, configuration)
    end

    before do
      # We stub this to avoid needing to set up a Rails app
      allow(Packwerk::RailsLoadPaths).to receive(:for).and_return({ 'packs/my_pack/app/services' => Object })
      write_pack('.')
      write_pack('packs/my_pack', { 'owner' => 'Foo' })
      write_file('packs/my_pack/app/services/my_pack.rb')
    end

    it 'does not create a validation error' do
      expect(validation_result.error_value).to be_nil
      expect(validation_result.ok?).to eq true
    end
  end
end
