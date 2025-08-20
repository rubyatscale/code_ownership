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

      context 'with errors' do
        it 'with errors' do
          expect { subject }.to raise_error(StandardError, /Some files are missing ownership/)
        end
      end

      context 'without errors' do
        before do
          write_file('config/teams/my_team.yml', <<~YML)
            name: My Team
            github:
              team: '@my-team'
            owned_globs:
            - app/**/*.rb
            - frontend/**/*.jsx
          YML
        end
        it 'has empty output' do
          expect(CodeOwnership::Cli).to_not receive(:puts)
          subject
        end
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
          expect { subject }.to raise_error StandardError
        end
      end
    end

    context 'with --skip-autocorrect' do
      let(:argv) { ['validate', '--skip-autocorrect'] }

      it 'passes autocorrect: false' do
        expect(CodeOwnership).to receive(:validate!) do |args|
          expect(args[:autocorrect]).to eq false
          expect(args[:stage_changes]).to eq true
        end
        subject
      end
    end

    context 'with --skip-stage' do
      let(:argv) { ['validate', '--skip-stage'] }

      it 'passes stage_changes: false' do
        expect(CodeOwnership).to receive(:validate!) do |args|
          expect(args[:autocorrect]).to eq true
          expect(args[:stage_changes]).to eq false
        end
        subject
      end
    end

    context 'with --help' do
      let(:argv) { ['validate', '--help'] }

      it 'shows help and exits' do
        expect(CodeOwnership).not_to receive(:validate!)
        expect(CodeOwnership::Cli).to receive(:puts).at_least(:once)
        expect { subject }.to raise_error(SystemExit)
      end
    end
  end

  context 'for_team' do
    before do
      write_configuration(owned_globs: nil)
      write_file('app/services/my_file.rb')
      write_file('config/teams/my_team.yml', <<~YML)
        name: My Team
        github:
          team: '@my-team'
        owned_globs:
        - app/**/*.rb
        - frontend/**/*.jsx
      YML
    end
    let(:argv) { ['for_team', 'My Team'] }

    it 'outputs the team info in human readable format' do
      expect(CodeOwnership::Cli).to receive(:puts).with('# Code Ownership Report for `My Team` Team')
      subject
    end

    context 'with no team provided' do
      let(:argv) { ['for_team'] }

      it 'raises argument error' do
        expect { subject }.to raise_error("Please pass in one team. Use `#{described_class::EXECUTABLE} for_team --help` for more info")
      end
    end

    context 'with multiple teams provided' do
      let(:argv) { %w[for_team A B] }

      it 'raises argument error' do
        expect { subject }.to raise_error("Please pass in one team. Use `#{described_class::EXECUTABLE} for_team --help` for more info")
      end
    end

    context 'with --help' do
      let(:argv) { ['for_team', '--help'] }

      it 'shows help and exits' do
        expect(CodeOwnership::Cli).to receive(:puts).at_least(:once)
        expect { subject }.to raise_error(SystemExit)
      end
    end
  end

  describe 'for_file' do
    before do
      write_configuration

      write_file('app/services/my_file.rb', <<~RB)
        class MyFile
          def initialize
            @team = 'My Team'
          end
        end
      RB
      write_file('config/teams/my_team.yml', <<~YML)
        name: My Team
        github:
          team: '@my-team'
        owned_globs:
        - app/**/*.rb
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

      context 'when run with --verbose' do
        let(:argv) { ['for_file', 'app/services/my_file.rb', '--verbose'] }

        it 'outputs the team info in human readable format' do
          expect(CodeOwnership::Cli).to receive(:puts).with(<<~MSG)
            Team: My Team
            Team YML: config/teams/my_team.yml
            Reasons:
            - Owner specified in Team YML as an owned_glob `app/**/*.rb`
          MSG
          subject
        end
      end

      context 'when run with no files' do
        let(:argv) { ['for_file'] }

        it 'outputs the team info in human readable format' do
          expect { subject }.to raise_error "Please pass in one file. Use `#{described_class::EXECUTABLE} for_file --help` for more info"
        end
      end

      context 'when run with multiple files' do
        let(:argv) { ['for_file', 'app/services/my_file.rb', 'app/services/my_file2.rb'] }

        it 'outputs the team info in human readable format' do
          expect { subject }.to raise_error "Please pass in one file. Use `#{described_class::EXECUTABLE} for_file --help` for more info"
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

        context 'when run with multiple files' do
          let(:argv) { ['for_file', '--json', '--verbose', 'app/services/my_file.rb'] }
          it 'outputs JSONified information to the console' do
            json = {
              team_name: 'My Team',
              team_yml: 'config/teams/my_team.yml',
              reasons: ['Owner specified in Team YML as an owned_glob `app/**/*.rb`']
            }
            expect(CodeOwnership::Cli).to receive(:puts).with(json.to_json)
            subject
          end  
        end
      end

      context 'when run with no files' do
        let(:argv) { ['for_file', '--json'] }

        it 'outputs the team info in human readable format' do
          expect { subject }.to raise_error "Please pass in one file. Use `#{described_class::EXECUTABLE} for_file --help` for more info"
        end
      end

      context 'when run with multiple files' do
        let(:argv) { ['for_file', 'app/services/my_file.rb', 'app/services/my_file2.rb'] }

        it 'outputs the team info in human readable format' do
          expect { subject }.to raise_error "Please pass in one file. Use `#{described_class::EXECUTABLE} for_file --help` for more info"
        end
      end
    end

    context 'when file is unowned' do
      let(:argv) { ['for_file', 'app/services/unowned.rb'] }

      it 'prints Unowned' do
        allow(CodeOwnership).to receive(:for_file).and_return(nil)
        expect(CodeOwnership::Cli).to receive(:puts).with(<<~MSG)
          Team: Unowned
          Team YML: Unowned
        MSG
        subject
      end

      context 'when run with --verbose' do
        let(:argv) { ['for_file', 'app/services/unowned.rb', '--verbose'] }

        it 'prints Unowned' do
          allow(CodeOwnership).to receive(:for_file_verbose).and_return(nil)
          expect(CodeOwnership::Cli).to receive(:puts).with(<<~MSG)
            Team: Unowned
            Team YML: Unowned
          MSG
          subject
        end
      end
    end

    context 'with --help' do
      let(:argv) { ['for_file', '--help'] }

      it 'shows help and exits' do
        expect(CodeOwnership::Cli).to receive(:puts).at_least(:once)
        expect { subject }.to raise_error(SystemExit)
      end
    end
  end

  describe 'version' do
    let(:argv) { ['version'] }

    it 'outputs the version' do
      expect(CodeOwnership::Cli).to receive(:puts).with(CodeOwnership.version.join("\n"))
      subject
    end
  end

  describe 'using unknown command' do
    let(:argv) { ['some_command'] }

    it 'outputs help text' do
      expect(CodeOwnership::Cli).to receive(:puts).with("'some_command' is not a code_ownership command. See `#{described_class::EXECUTABLE} help`.")
      subject
    end
  end

  describe 'passing in no command' do
    let(:argv) { [] }

    it 'outputs help text' do
      expected = <<~EXPECTED
        Usage: #{described_class::EXECUTABLE} <subcommand>

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
