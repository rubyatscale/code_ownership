# frozen_string_literal: true

module CodeOwnership
  RSpec.describe Private::OwnershipMappers::FileOwner do
    describe 'CodeOwnershp.for_file' do
      subject { described_class.for_file(file_path, directory_cache) }
      let(:directory_cache) { {} }
      before do
        write_configuration

        write_file('a/b/.codeowner', <<~CONTENTS)
          Bar
        CONTENTS
        write_file('z/y/x/x_file.jsx')
        write_file('a/b/c/c_file.jsx')
        write_file('a/b/b_file.jsx')
        write_file('a/b/c/d/e/f/g/h_file.jsx')
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS
      end

      context 'when file provided' do
        let(:file_path) { 'a/b/b_file.jsx' }

        it 'can find the owner of files in team-owned directory' do
          expect(subject.name).to eq 'Bar'
        end

        context 'when un-owned file' do
          let(:file_path) { 'z/y/x/x_file.jsx' }
          it 'returns nil' do
            expect(subject).to be_nil
          end
        end
      end

      context 'when directory provided' do
        let(:file_path) { 'a/b' }

        it 'can find the owner of files in team-owned directory' do
          expect(subject.name).to eq 'Bar'
        end

        context 'when deeply nested directory' do
          let(:file_path) { 'a/b/c/d/e/f/g' }

          it 'can find the owner of files in team-owned directory' do
            expect(subject.name).to eq 'Bar'
          end
        end

        context 'when un-owned directory' do
          let(:file_path) { 'z/y' }
          it 'returns nil' do
            expect(subject).to be_nil
          end
        end
      end
    end
  end
end
