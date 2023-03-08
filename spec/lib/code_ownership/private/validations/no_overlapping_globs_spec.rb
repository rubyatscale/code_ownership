module CodeOwnership
  RSpec.describe Private::Validations::NoOverlappingGlobs do
    describe 'CodeOwnership.validate!' do
      context 'two teams own the same exact glob' do
        before do
          write_file('config/code_ownership.yml', <<~YML)
            owned_globs:
              - '{app,components,config,frontend,lib,packs,spec}/**/*.{rb,rake,js,jsx,ts,tsx}'
          YML

          write_file('packs/my_pack/owned_file.rb')
          write_file('frontend/javascripts/blah/my_file.rb')
          write_file('frontend/javascripts/blah/subdir/my_file.rb')

          write_file('config/teams/bar.yml', <<~CONTENTS)
            name: Bar
            owned_globs:
              - packs/**/**
              - frontend/javascripts/blah/subdir/my_file.rb
          CONTENTS

          write_file('config/teams/foo.yml', <<~CONTENTS)
            name: Foo
            owned_globs:
              - packs/**/**
              - frontend/javascripts/blah/**/**
          CONTENTS
        end

        it 'lets the user know that `owned_globs` can not overlap' do
          expect { CodeOwnership.validate! }.to raise_error do |e|
            expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
            puts e.message
            expect(e.message).to eq <<~EXPECTED.chomp
              `owned_globs` cannot overlap between teams. The following globs overlap:

              - `packs/**/**` (from `config/teams/bar.yml`), `packs/**/**` (from `config/teams/foo.yml`)
              - `frontend/javascripts/blah/subdir/my_file.rb` (from `config/teams/bar.yml`), `frontend/javascripts/blah/**/**` (from `config/teams/foo.yml`)

              See https://github.com/rubyatscale/code_ownership#README.md for more details
            EXPECTED
          end
        end
      end
    end
  end
end
