module CodeOwnership
  RSpec.describe Private::OwnershipMappers::TeamGlobs do
    before { write_configuration }

    describe 'CodeOwnership.for_file' do
      before do
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
          owned_globs:
            - app/services/bar_stuff/**/**
            - frontend/javascripts/bar_stuff/**/**
            - '**/team_thing/**/*'
          unowned_globs:
            - shared/**/team_thing/**/*
        CONTENTS

        write_file('app/services/bar_stuff/thing.rb')
        write_file('app/services/bar_stuff/[test]/thing.rb')
        write_file('frontend/javascripts/bar_stuff/thing.jsx')
        write_file('app/services/team_thing/thing.rb')
        write_file('shared/config/team_thing/something.rb')
      end

      it 'can find the owner of ruby files in owned_globs' do
        expect(CodeOwnership.for_file('app/services/bar_stuff/thing.rb').name).to eq 'Bar'
        expect(CodeOwnership.for_file('app/services/bar_stuff/[test]/thing.rb').name).to eq 'Bar'
        expect(CodeOwnership.for_file('app/services/team_thing/thing.rb').name).to eq 'Bar'
      end

      it 'does not find the owner of ruby files in unowned_globs' do
        expect(CodeOwnership.for_file('shared/config/team_thing/something.rb')).to be_nil
      end

      it 'can find the owner of javascript files in owned_globs' do
        expect(CodeOwnership.for_file('frontend/javascripts/bar_stuff/thing.jsx').name).to eq 'Bar'
      end
    end

    describe 'CodeOwnership.validate!' do
      context 'has unowned globs' do
        before do
          write_file('config/teams/bar.yml', <<~CONTENTS)
            name: Bar
            owned_globs:
              - app/services/bar_stuff/**/**
              - frontend/javascripts/bar_stuff/**/**
              - '**/team_thing/**/*'
            unowned_globs:
              - shared/**/team_thing/**/*
          CONTENTS
        end

        it 'considers the combination of owned_globs and unowned_globs' do
          expect { CodeOwnership.validate! }.to_not raise_error
        end
      end

      context 'two teams own the same exact glob' do
        before do
          write_configuration

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
