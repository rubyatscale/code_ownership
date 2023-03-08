RSpec.describe CodeOwnership do
  # Look at individual validations spec to see other validaions that ship with CodeOwnership
  describe '.validate!' do
    let(:codeowners_validation) { CodeOwnership.const_get(:Private)::Validations::GithubCodeownersUpToDate }

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

    context 'application has invalid JSON in package' do
      before do
        write_file('config/code_ownership.yml', {}.to_yaml)

        write_file('frontend/javascripts/my_package/package.json', <<~CONTENTS)
          { syntax error!!!
            "metadata": {
              "owner": "Foo"
            }
          }
        CONTENTS
      end

      it 'lets the user know the their package JSON is invalid' do
        expect { CodeOwnership.validate! }.to raise_error do |e|
          expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
          expect(e.message).to match /JSON::ParserError.*?unexpected token/
          expect(e.message).to include 'frontend/javascripts/my_package/package.json has invalid JSON, so code ownership cannot be determined.'
          expect(e.message).to include 'Please either make the JSON in that file valid or specify `js_package_paths` in config/code_ownership.yml.'
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

    it 'can find the owner of files in team-owned javascript packages' do
      expect(CodeOwnership.for_file('frontend/javascripts/packages/my_other_package/my_file.jsx')).to eq CodeTeams.find('Bar')
    end
  end

  describe '.for_backtrace' do
    before do
      create_files_with_defined_classe
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
      create_files_with_defined_classe
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
    before { create_files_with_defined_classe }

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
  end

  describe '.for_package' do
    before { create_non_empty_application }

    it 'returns the right team' do
      team = CodeOwnership.for_package(Packs.find('packs/my_other_package'))
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

        write_file('package.yml', <<~CONTENTS)
          enforce_dependency: true
          enforce_privacy: true
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

        write_file('package.yml', <<~CONTENTS)
          enforce_dependency: true
          enforce_privacy: true
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

        ## Owner metadata key in package.yml
        - packs/my_other_package/**/**

        ## Owner metadata key in package.json
        - frontend/javascripts/packages/my_other_package/**/**

        ## Team YML ownership
        - config/teams/bar.yml
      OWNERSHIP
    end

    context 'team does not own any packs or files using annotations' do
      before do
        write_file('config/teams/foo.yml', <<~CONTENTS)
          name: Foo
          github:
            team: '@MyOrg/foo-team'
          owned_globs:
            - app/services/foo_stuff/**
        CONTENTS
      end

   it 'prints out ownership information for the given team' do
      expect(CodeOwnership.for_team('Foo')).to eq <<~OWNERSHIP
        # Code Ownership Report for `Foo` Team
        ## Annotations at the top of file
        This team owns nothing in this category.

        ## Team-specific owned globs
        - app/services/foo_stuff/**

        ## Owner metadata key in package.yml
        This team owns nothing in this category.

        ## Owner metadata key in package.json
        This team owns nothing in this category.

        ## Team YML ownership
        - config/teams/foo.yml
      OWNERSHIP
    end
    end
  end
end
