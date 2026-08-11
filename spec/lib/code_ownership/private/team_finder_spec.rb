# frozen_string_literal: true

RSpec.describe CodeOwnership::Private::TeamFinder do
  describe '.for_file' do
    let(:file_path) { 'packs/my_pack/owned_file.rb' }

    let(:rust_result) do
      { team_name: 'Bar', team_config_yml: 'config/teams/bar.yml', reasons: [] }
    end

    before do
      create_non_empty_application
    end

    it 'caches positive results' do
      allow(RustCodeOwners).to receive(:for_file).with(file_path)
        .and_return(rust_result, nil)

      first = described_class.for_file(file_path)
      second = described_class.for_file(file_path)

      expect(first).to eq(CodeTeams.find('Bar'))
      expect(second).to eq(CodeTeams.find('Bar'))
      expect(CodeOwnership::Private::FilePathTeamCache.cached?(file_path)).to be true
    end

    it 'caches nil when rust returns nil' do
      allow(RustCodeOwners).to receive(:for_file).with(file_path)
        .and_return(nil, rust_result)

      first = described_class.for_file(file_path)
      second = described_class.for_file(file_path)

      expect(first).to be_nil
      expect(second).to be_nil
      expect(CodeOwnership::Private::FilePathTeamCache.cached?(file_path)).to be true
    end
  end

  describe '.for_backtrace' do
    it 'returns nil for nil backtrace' do
      expect(described_class.for_backtrace(nil)).to be_nil
    end
  end

  describe '.first_owned_file_for_backtrace' do
    it 'returns nil for nil backtrace' do
      expect(described_class.first_owned_file_for_backtrace(nil)).to be_nil
    end
  end
end
