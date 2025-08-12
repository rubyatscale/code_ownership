# frozen_string_literal: true

RSpec.describe CodeOwnership do
  it 'has a version number' do
    expect(CodeOwnership::VERSION).not_to be nil
  end

  describe '.for_file' do
    subject { CodeOwnership.for_file(file_path) }
    context 'rust codeowners' do
      context 'when config is not found' do
        let(:file_path) { 'app/javascript/[test]/test.js' }
        it 'raises an error' do
          expect { subject }.to raise_error(RuntimeError, /Can't open config file:/)
        end
      end

      context 'with non-empty application' do
        before do
          create_non_empty_application
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
        end

        context 'when ownership is found but team is not found' do
          let(:file_path) { 'packs/my_pack/owned_file.rb' }
          before do
            allow(RustCodeOwners).to receive(:for_file).and_return({ team_name: 'Made Up Team' })
          end

          it 'raises an error' do
            expect { subject }.to raise_error(StandardError, /Could not find team with name: `Made Up Team`. Make sure the team is one of/)
          end
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
  end
end
