# frozen_string_literal: true

RSpec.describe CodeOwnership do
  it 'has a version number' do
    expect(CodeOwnership::VERSION).not_to be nil
  end

  context 'teams_for_files_from_codeowners' do
    subject { CodeOwnership.teams_for_files_from_codeowners(files) }
    let(:files) { ['app/services/my_file.rb'] }

    context 'when config is not found' do
      let(:files) { ['app/javascript/[test]/test.js'] }
      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, /Can't open config file:/)
      end
    end

    context 'with non-empty application' do
      before do
        create_non_empty_application
        # codeowners-rs is matching files against the codeowners file
        RustCodeOwners.generate_and_validate(nil, false)
      end

      context 'when no ownership is found' do
        let(:files) { ['app/madeup/file.rb'] }
        it 'properly assigns ownership' do
          expect(subject).to eq({ 'app/madeup/file.rb' => nil })
        end
      end

      context 'when file path starts with ./' do
        let(:files) { ['./app/javascript/[test]/test.js'] }
        it 'properly assigns ownership' do
          expect(subject).to eq({ './app/javascript/[test]/test.js' => nil })
        end
      end

      context 'when ownership is found' do
        let(:files) { ['packs/my_pack/owned_file.rb'] }
        it 'returns the correct team' do
          expect(subject).to eq({ 'packs/my_pack/owned_file.rb' => CodeTeams.find('Bar') })
        end

        context 'subsequent for_file utilizes cached team' do
          let(:files) { ['packs/my_pack/owned_file.rb', 'packs/my_pack/owned_file2.rb'] }
          it 'returns the correct team' do
            subject # caches paths -> teams
            allow(RustCodeOwners).to receive(:for_file)
            expect(described_class.for_file('packs/my_pack/owned_file.rb')).to eq(CodeTeams.find('Bar'))
            expect(RustCodeOwners).to_not have_received(:for_file)
          end
        end
      end

      context 'when ownership is found but team is not found' do
        let(:file_path) { ['packs/my_pack/owned_file.rb'] }
        before do
          allow(RustCodeOwners).to receive(:teams_for_files).and_return({ file_path.first => { team_name: 'Made Up Team' } })
        end

        it 'returns nil' do
          expect(subject).to eq({ 'packs/my_pack/owned_file.rb' => nil })
        end
      end

      context 'when ownership is found but team is not found and allow_raise is true' do
        let(:files) { ['packs/my_pack/owned_file.rb'] }
        before do
          allow(RustCodeOwners).to receive(:teams_for_files).and_return({ files.first => { team_name: 'Made Up Team' } })
        end

        it 'raises an error' do
          expect { CodeOwnership.teams_for_files_from_codeowners(files, allow_raise: true) }.to raise_error(StandardError, /Could not find team with name:/)
        end
      end
    end
  end

  describe '.for_file_from_codeowners' do
    subject { CodeOwnership.for_file(file_path, from_codeowners: true) }

    context 'when config is not found' do
      let(:file_path) { 'app/javascript/[test]/test.js' }
      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, /Can't open config file:/)
      end
    end

    context 'with non-empty application' do
      before do
        create_non_empty_application
        # codeowners-rs is matching files against the codeowners file
        RustCodeOwners.generate_and_validate(nil, false)
      end

      context 'when no ownership is found' do
        let(:file_path) { 'app/madeup/file.rb' }
        it 'properly assigns ownership' do
          expect(subject).to be_nil
        end
      end

      context 'when file path starts with ./' do
        let(:file_path) { './app/javascript/[test]/test.js' }
        it 'properly assigns ownership' do
          expect(subject).to be_nil
        end
      end

      context 'when ownership is found' do
        let(:file_path) { 'packs/my_pack/owned_file.rb' }
        it 'returns the correct team' do
          expect(subject).to eq CodeTeams.find('Bar')
        end

        context 'subsequent for_file utilizes cached team' do
          it 'returns the correct team' do
            subject # caches path -> team
            allow(RustCodeOwners).to receive(:for_file)
            expect(described_class.for_file(file_path)).to eq(CodeTeams.find('Bar'))
            expect(RustCodeOwners).to_not have_received(:for_file)
          end
        end
      end

      context 'when ownership is found but team is not found' do
        let(:file_path) { 'packs/my_pack/owned_file.rb' }
        before do
          allow(RustCodeOwners).to receive(:teams_for_files).and_return({ file_path => { team_name: 'Made Up Team' } })
        end

        it 'returns nil' do
          expect(subject).to be_nil
        end
      end

      context 'when ownership is found but team is not found and allow_raise is true' do
        let(:file_path) { 'packs/my_pack/owned_file.rb' }
        before do
          allow(RustCodeOwners).to receive(:teams_for_files).and_return({ file_path => { team_name: 'Made Up Team' } })
        end

        it 'raises an error' do
          expect { CodeOwnership.for_file(file_path, from_codeowners: true, allow_raise: true) }.to raise_error(StandardError, /Could not find team with name:/)
        end
      end
    end
  end

  describe '.for_file' do
    subject { CodeOwnership.for_file(file_path) }
    context 'when config is not found' do
      let(:file_path) { 'app/javascript/[test]/test.js' }
      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, /Can't open config file:/)
      end
    end

    context 'with non-empty application' do
      before do
        create_non_empty_application
        # codeowners-rs is matching files against the codeowners file for default path
        RustCodeOwners.generate_and_validate(nil, false)
      end

      context 'when no ownership is found' do
        let(:file_path) { 'app/madeup/file.rb' }
        it 'properly assigns ownership' do
          expect(subject).to be_nil
        end
      end

      context 'when file path starts with ./' do
        let(:file_path) { './app/javascript/[test]/test.js' }
        it 'properly assigns ownership' do
          expect(subject).to be_nil
        end
      end

      context 'when ownership is found' do
        let(:file_path) { 'packs/my_pack/owned_file.rb' }
        it 'returns the correct team' do
          expect(subject).to eq CodeTeams.find('Bar')
        end

        context 'when ownership is cached' do
          it 'returns the correct team' do
            expect(subject).to eq CodeTeams.find('Bar')
            allow(RustCodeOwners).to receive(:teams_for_files)
            expect(CodeOwnership.for_file(file_path)).to eq CodeTeams.find('Bar')
            expect(RustCodeOwners).not_to have_received(:teams_for_files)
          end
        end
      end

      context 'when ownership is found but team is not found' do
        let(:file_path) { 'packs/my_pack/owned_file.rb' }
        before do
          allow(RustCodeOwners).to receive(:teams_for_files).and_return({ file_path => { team_name: 'Made Up Team' } })
        end

        it 'returns nil by default' do
          expect(subject).to be_nil
        end
      end

      context 'when ownership is found but team is not found and allow_raise is true' do
        let(:file_path) { 'packs/my_pack/owned_file.rb' }

        it 'raises an error when using from_codeowners path' do
          allow(RustCodeOwners).to receive(:teams_for_files).and_return({ file_path => { team_name: 'Made Up Team' } })
          expect { CodeOwnership.for_file(file_path, allow_raise: true) }.to raise_error(StandardError, /Could not find team with name:/)
        end

        it 'raises an error when using single-file path' do
          allow(RustCodeOwners).to receive(:for_file).and_return({ team_name: 'Made Up Team' })
          expect { CodeOwnership.for_file(file_path, from_codeowners: false, allow_raise: true) }.to raise_error(StandardError, /Could not find team with name:/)
        end
      end
    end
  end

  describe '.for_class' do
    subject { described_class.for_class(klass) }

    let(:klass) do
      described_class
    end
    let(:file_path) { 'packs/my_pack/owned_file.rb' }

    before do
      allow(CodeOwnership::Private::FilePathFinder).to receive(:path_from_klass).and_return(file_path)
    end

    context 'when the klass path is found' do
      before do
        create_non_empty_application
      end

      it 'calls for_file with the correct file path' do
        subject
        expect(CodeOwnership::Private::FilePathFinder).to have_received(:path_from_klass).with(klass)
      end

      it 'returns the correct team' do
        expect(subject).to eq CodeTeams.find('Bar')
      end
    end

    context 'when the klass path is not found' do
      let(:file_path) { nil }
      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '.for_package' do
    subject { described_class.for_package(package) }

    let(:package_yml_path) { 'packs/my_pack/package.yml' }

    before do
      create_non_empty_application
      write_file(package_yml_path, raw_hash.to_yaml)
    end

    let(:package) do
      Packs::Pack.from(Pathname.new(package_yml_path).realpath)
    end

    context 'with owner set' do
      let(:raw_hash) { { 'owner' => 'Bar' } }

      it 'returns the correct team' do
        expect(subject).to eq CodeTeams.find('Bar')
      end
    end

    context 'with metadata owner set' do
      let(:raw_hash) { { 'metadata' => { 'owner' => 'Bar' } } }

      it 'returns the correct team' do
        expect(subject).to eq CodeTeams.find('Bar')
      end
    end

    context 'with no owner set' do
      let(:raw_hash) { {} }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'with unknown owner' do
      let(:raw_hash) { { 'owner' => 'Does Not Exist' } }

      it 'raises helpful error' do
        expect { subject }.to raise_error(StandardError, /Could not find team with name:/)
      end
    end

    context 'with empty owner string' do
      let(:raw_hash) { { 'owner' => '' } }

      it 'raises helpful error' do
        expect { subject }.to raise_error(StandardError, /Could not find team with name:/)
      end
    end
  end

  describe '.for_backtrace' do
    before do
      create_files_with_defined_classes
      write_configuration
    end

    context 'excluded_teams is not passed in as an input parameter' do
      it 'finds the right team' do
        expect { MyFile.raise_error }.to raise_error do |ex|
          expect(described_class.for_backtrace(ex.backtrace)).to eq CodeTeams.find('Bar')
        end
      end
    end

    context 'excluded_teams is passed in as an input parameter' do
      it 'ignores the first part of the stack trace and finds the next viable owner' do
        expect { MyFile.raise_error }.to raise_error do |ex|
          team_to_exclude = CodeTeams.find('Bar')
          expect(described_class.for_backtrace(ex.backtrace, excluded_teams: [team_to_exclude])).to eq CodeTeams.find('Foo')
        end
      end
    end

    context 'with nil backtrace' do
      it 'returns nil' do
        expect(described_class.for_backtrace(nil)).to be_nil
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
          expect(described_class.first_owned_file_for_backtrace(ex.backtrace)).to eq [CodeTeams.find('Bar'), 'app/my_error.rb']
        end
      end
    end

    context 'excluded_teams is not passed in as an input parameter' do
      it 'finds the right team' do
        expect { MyFile.raise_error }.to raise_error do |ex|
          team_to_exclude = CodeTeams.find('Bar')
          expect(described_class.first_owned_file_for_backtrace(ex.backtrace, excluded_teams: [team_to_exclude])).to eq [CodeTeams.find('Foo'), 'app/my_file.rb']
        end
      end
    end

    context 'when nothing is owned' do
      it 'returns nil' do
        expect { raise 'bang!' }.to raise_error do |ex|
          expect(described_class.first_owned_file_for_backtrace(ex.backtrace)).to be_nil
        end
      end
    end

    context 'with nil backtrace' do
      it 'returns nil' do
        expect(described_class.first_owned_file_for_backtrace(nil)).to be_nil
      end
    end
  end

  describe '.version' do
    it 'returns the version' do
      expect(described_class.version).to eq ["code_ownership version: #{CodeOwnership::VERSION}", "codeowners-rs version: #{RustCodeOwners.version}"]
    end
  end
end
