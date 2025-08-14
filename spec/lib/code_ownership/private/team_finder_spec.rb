# frozen_string_literal: true

RSpec.describe CodeOwnership::Private::TeamFinder do
  describe '.for_file' do
    let(:file_path) { 'packs/my_pack/owned_file.rb' }

    before do
      create_non_empty_application
    end

    it 'caches positive results' do
      allow(RustCodeOwners).to receive(:for_file).with(file_path)
        .and_return({ team_name: 'Bar' }, nil)

      first = described_class.for_file(file_path)
      second = described_class.for_file(file_path)

      expect(first).to eq(CodeTeams.find('Bar'))
      expect(second).to eq(CodeTeams.find('Bar'))
      expect(CodeOwnership::Private::FilePathTeamCache.cached?(file_path)).to be true
    end

    it 'does not cache when rust returns nil' do
      allow(RustCodeOwners).to receive(:for_file).with(file_path).and_return(nil)

      expect(described_class.for_file(file_path)).to be_nil
      expect(CodeOwnership::Private::FilePathTeamCache.cached?(file_path)).to be false
    end

    it 'caches nil when team_name is nil' do
      allow(RustCodeOwners).to receive(:for_file).with(file_path).and_return({ team_name: nil })

      expect(described_class.for_file(file_path)).to be_nil
      expect(CodeOwnership::Private::FilePathTeamCache.cached?(file_path)).to be true
      expect(CodeOwnership::Private::FilePathTeamCache.get(file_path)).to be_nil
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
