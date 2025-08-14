# frozen_string_literal: true

RSpec.describe CodeOwnership::Private::FilePathTeamCache do
  let(:file_path) { 'app/javascript/[test]/test.js' }
  let(:codes_team) { instance_double(CodeTeams::Team) }

  describe '.get' do
    subject { described_class.get(file_path) }

    context 'when the file path is not in the cache' do
      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when the file path is in the cache' do
      before do
        described_class.set(file_path, codes_team)
      end

      it 'returns the correct team' do
        expect(subject).to eq codes_team
      end

      context 'when cache is busted' do
        before do
          described_class.bust_cache!
        end

        it 'returns nil' do
          expect(subject).to be_nil
        end
      end
    end
  end

  describe '.cached?' do
    subject { described_class.cached?(file_path) }

    context 'when the file path is not in the cache' do
      it 'returns false' do
        expect(subject).to be_falsey
      end
    end

    context 'when the file path is in the cache' do
      before do
        described_class.set(file_path, codes_team)
      end

      it 'returns true' do
        expect(subject).to be_truthy
      end
    end
  end
end
