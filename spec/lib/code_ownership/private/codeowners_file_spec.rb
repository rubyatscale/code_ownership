module CodeOwnership
  RSpec.describe Private::CodeownersFile do
    describe '.path' do
      subject { described_class.path }

      context 'when the environment variable is set' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('CODEOWNERS_PATH', anything).and_return(path)
        end

        context "to 'foo'" do
          let(:path) { 'foo' }

          it 'uses the environment variable' do
            expect(subject).to eq(Pathname.pwd.join('foo', 'CODEOWNERS'))
          end
        end

        context 'to empty' do
          let(:path) { '' }

          it 'uses the environment variable' do
            expect(subject).to eq(Pathname.pwd.join('CODEOWNERS'))
          end
        end
      end

      context 'when the environment variable is not set' do
        it 'uses the default' do
          expect(subject).to eq(Pathname.pwd.join('.github', 'CODEOWNERS'))
        end
      end
    end
  end
end
