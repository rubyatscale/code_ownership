RSpec.describe CodeOwnership::Cli do
  subject { CodeOwnership::Cli.run!(argv) }

  describe 'validate' do
    let(:argv) { ['validate'] }

    before do
      write_file('config/code_ownership.yml', <<~YML)
        owned_globs:
          - 'app/**/*.rb'
      YML

      write_file('app/services/my_file.rb')
      write_file('frontend/javascripts/my_file.jsx')
    end

    context 'when run without arguments' do
      it 'runs validations with the right defaults' do
        expect(CodeOwnership).to receive(:validate!) do |args| # rubocop:disable RSpec/MessageSpies
          expect(args[:autocorrect]).to eq true
          expect(args[:stage_changes]).to eq true
          expect(args[:files]).to match_array(['app/services/my_file.rb'])
        end
        subject
      end
    end

  end

  describe 'for_file' do
    before do
      write_file('config/code_ownership.yml', <<~YML)
        owned_globs:
          - 'app/**/*.rb'
      YML

      write_file('app/services/my_file.rb')
    end

    # context 'when run with no flags' do
    #   context 'when run with one file' do
        
    #   end
    # end

    context 'when run with --json' do
      let(:argv) { ['for_file', '--json', 'app/services/my_file.rb'] }

      context 'when run with one file' do
        it 'outputs JSONified information to the console'
      end
    end
  end
end
