module CodeOwnership
  RSpec.describe Private::OwnershipMappers::TeamGlobs do
    before do
      create_configuration
      write_file('config/teams/bar.yml', <<~CONTENTS)
        name: Bar
        owned_globs:
          - app/services/bar_stuff/**/**
          - frontend/javascripts/bar_stuff/**/**
      CONTENTS

      write_file('app/services/bar_stuff/thing.rb')
      write_file('frontend/javascripts/bar_stuff/thing.jsx')
    end

    it 'can find the owner of ruby files in owned_globs' do
      expect(CodeOwnership.for_file('app/services/bar_stuff/thing.rb').name).to eq 'Bar'
    end

    it 'can find the owner of javascript files in owned_globs' do
      expect(CodeOwnership.for_file('frontend/javascripts/bar_stuff/thing.jsx').name).to eq 'Bar'
    end
  end
end
