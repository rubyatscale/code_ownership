RSpec.describe CodeOwnership::Private::CodeownersFile do
  describe '.path' do
    subject { described_class.path }

    context 'when codeowners_path is set in the configuration' do
      let(:configuration) do
        Configuration.new(
          owned_globs: [],
          unowned_globs: [],
          js_package_paths: [],
          unbuilt_gems_path: nil,
          skip_codeowners_validation: false,
          raw_hash: {},
          require_github_teams: false,
          codeowners_path: path
        )
      end

      before do
        allow(CodeOwnership).to receive(:configuration).and_return(configuration)
      end

      context "when set to 'foo'" do
        let(:path) { 'foo' }

        it 'uses the environment variable' do
          expect(subject).to eq(Pathname.pwd.join('foo', 'CODEOWNERS'))
        end
      end

      context 'when set to empty' do
        let(:path) { '' }

        it 'uses the environment variable' do
          expect(subject).to eq(Pathname.pwd.join('CODEOWNERS'))
        end
      end
    end
  end
end
