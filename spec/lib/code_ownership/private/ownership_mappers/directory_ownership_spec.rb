module CodeOwnership
  RSpec.describe Private::OwnershipMappers::JsPackageOwnership do
    describe 'CodeOwnershp.for_file' do
      before do
        write_configuration

        write_file('a/b/.codeowner', <<~CONTENTS)
          Bar
        CONTENTS
        write_file('a/b/c/c_file.jsx')
        write_file('a/b/b_file.jsx')
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS
      end

      it 'can find the owner of files in team-owned directory' do
        expect(CodeOwnership.for_file('a/b/b_file.jsx').name).to eq 'Bar'
      end

      it 'can find the owner of files in a sub-directory of a team-owned directory' do
        expect(CodeOwnership.for_file('a/b/c/c_file.jsx').name).to eq 'Bar'
      end

      it 'looks for codeowner file within directory' do
        expect(CodeOwnership.for_file('a/b').name).to eq 'Bar'
        expect(CodeOwnership.for_file(Pathname.pwd.join('a/b').to_s).name).to eq 'Bar'
      end
    end
  end
end
