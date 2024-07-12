RSpec.describe CodeOwnership::Cli do
  subject { CodeOwnership::Cli.run!(argv) }

  describe 'validate' do
    let(:argv) { ['validate'] }
    let(:owned_globs) { nil }

    before do
      write_configuration(owned_globs: owned_globs)
      write_file('app/services/my_file.rb')
      write_file('frontend/javascripts/my_file.jsx')
    end

    context 'when run without arguments' do
      it 'runs validations with the right defaults' do
        expect(CodeOwnership).to receive(:validate!) do |args|
          expect(args[:autocorrect]).to eq true
          expect(args[:stage_changes]).to eq true
          expect(args[:files]).to be_nil
        end
        subject
      end
    end

    context 'with --diff argument' do
      let(:argv) { ['validate', '--diff'] }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('CODEOWNERS_GIT_STAGED_FILES').and_return('app/services/my_file.rb')
      end

      context 'when there are multiple owned_globs' do
        let(:owned_globs) { ['app/*/**', 'lib/*/**'] }

        it 'validates the tracked file' do
          expect { subject }.to raise_error CodeOwnership::InvalidCodeOwnershipConfigurationError
        end
      end
    end
  end

  describe 'for_file' do
    before do
      write_configuration

      write_file('app/services/my_file.rb')
      write_file('config/teams/my_team.yml', <<~YML)
        name: My Team
        owned_globs:#{' '}
          - 'app/**/*.rb'
      YML
    end

    context 'when run with no flags' do
      context 'when run with one file' do
        let(:argv) { ['for_file', 'app/services/my_file.rb'] }

        it 'outputs the team info in human readable format' do
          expect(CodeOwnership::Cli).to receive(:puts).with(<<~MSG)
            Team: My Team
            Team YML: config/teams/my_team.yml
          MSG
          subject
        end
      end

      context 'when run with no files' do
        let(:argv) { ['for_file'] }

        it 'outputs the team info in human readable format' do
          expect { subject }.to raise_error 'Please pass in one file. Use `bin/codeownership for_file --help` for more info'
        end
      end

      context 'when run with multiple files' do
        let(:argv) { ['for_file', 'app/services/my_file.rb', 'app/services/my_file2.rb'] }

        it 'outputs the team info in human readable format' do
          expect { subject }.to raise_error 'Please pass in one file. Use `bin/codeownership for_file --help` for more info'
        end
      end
    end

    context 'when run with --json' do
      let(:argv) { ['for_file', '--json', 'app/services/my_file.rb'] }

      context 'when run with one file' do
        it 'outputs JSONified information to the console' do
          json = {
            team_name: 'My Team',
            team_yml: 'config/teams/my_team.yml'
          }
          expect(CodeOwnership::Cli).to receive(:puts).with(json.to_json)
          subject
        end
      end

      context 'when run with no files' do
        let(:argv) { ['for_file', '--json'] }

        it 'outputs the team info in human readable format' do
          expect { subject }.to raise_error 'Please pass in one file. Use `bin/codeownership for_file --help` for more info'
        end
      end

      context 'when run with multiple files' do
        let(:argv) { ['for_file', 'app/services/my_file.rb', 'app/services/my_file2.rb'] }

        it 'outputs the team info in human readable format' do
          expect { subject }.to raise_error 'Please pass in one file. Use `bin/codeownership for_file --help` for more info'
        end
      end
    end
  end

  describe 'using unknown command' do
    let(:argv) { ['some_command'] }

    it 'outputs help text' do
      expect(CodeOwnership::Cli).to receive(:puts).with("'some_command' is not a code_ownership command. See `bin/codeownership help`.")
      subject
    end
  end

  describe 'passing in no command' do
    let(:argv) { [] }

    it 'outputs help text' do
      expected = <<~EXPECTED
        Usage: bin/codeownership <subcommand>

        Subcommands:
          validate - run all validations
          for_file - find code ownership for a single file
          for_team - find code ownership information for a team
          help  - display help information about code_ownership
      EXPECTED
      expect(CodeOwnership::Cli).to receive(:puts).with(expected)
      subject
    end
  end
end
