RSpec.describe CodeOwnership do
  # Look at individual validations spec to see other validaions that ship with CodeOwnership
  describe '.validate!' do
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
      create_minimal_configuration
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
      create_minimal_configuration
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
      create_minimal_configuration
    end

    let(:klass) { MyFile }
    subject { CodeOwnership.for_class(klass) }

    it 'can find the right owner for a class' do
      expect(subject).to eq CodeTeams.find('Foo')
    end

    it 'memoizes the values' do
      expect(subject).to eq CodeTeams.find('Foo')
      allow(CodeOwnership).to receive(:for_file)
      allow(Object).to receive(:const_source_location)
      expect(subject).to eq CodeTeams.find('Foo')

      # Memoization should avoid these calls
      expect(CodeOwnership).to_not have_received(:for_file)
      expect(Object).to_not have_received(:const_source_location)
    end

    context 'when called with nil' do
      let(:klass) { nil }

      it 'should return nil' do
        expect(subject).to be_nil
      end
    end

    context 'with an anonymous class (string)' do
      let(:klass) { "#<Class:0x0000000141ef64a0>" }

      it 'should return nil' do
        expect(subject).to be_nil
      end
    end

    context 'with a string that represents a constant which does not exist' do
      let(:klass) { "Yeehaw" }

      it 'should return nil' do
        expect(subject).to be_nil
      end
    end

    # Stubbing to simulate. See docs of Module#const_source_location.
    # If the named constant is not found, nil is returned.
    # If the constant is found, but its source location can not be extracted
    # (constant is defined in C code), empty array is returned.
    context 'with a constant defined in C' do
      let(:klass) { "Yeehaw" }
      before { allow(Object).to receive(:const_source_location).and_return([]) }

      it 'should return nil' do
        expect(subject).to be_nil
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
  end
end
