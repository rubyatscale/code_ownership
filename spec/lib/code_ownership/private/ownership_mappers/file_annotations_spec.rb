RSpec.describe CodeOwnership::Private::OwnershipMappers::FileAnnotations do
  describe '.for_team' do
    before do
      write_configuration
      write_file('config/teams/bar.yml', <<~CONTENTS)
        name: Bar
      CONTENTS

      write_file('packs/my_pack/owned_file.rb', <<~CONTENTS)
        # @team Bar
      CONTENTS
    end

    it 'prints out ownership information for the given team' do
      expect(CodeOwnership.for_team('Bar')).to eq <<~OWNERSHIP
        # Code Ownership Report for `Bar` Team
        ## Annotations at the top of file
        - packs/my_pack/owned_file.rb

        ## Team-specific owned globs
        This team owns nothing in this category.

        ## Owner in .codeowner
        This team owns nothing in this category.

        ## Owner metadata key in package.yml
        This team owns nothing in this category.

        ## Owner metadata key in package.json
        This team owns nothing in this category.

        ## Team YML ownership
        - config/teams/bar.yml
      OWNERSHIP
    end
  end

  describe '.for_file' do
    context 'when path is a directory' do
      it 'returns nil' do
        write_configuration
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS

        expect(CodeOwnership.for_file('config/teams')).to be_nil
      end
    end

    context 'when path does not exist' do
      it 'returns nil' do
        write_configuration
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS

        expect(CodeOwnership.for_file('config/teams/foo.yml')).to be_nil
      end
    end

    context 'with ruby owned file' do
      before do
        write_configuration
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS

        write_file('packs/my_pack/owned_file.rb', <<~CONTENTS)
          # @team Bar
        CONTENTS
      end

      it 'can find the owner of a ruby file with file annotations' do
        expect(CodeOwnership.for_file('packs/my_pack/owned_file.rb').name).to eq 'Bar'
      end
    end

    context 'with javascript owned file' do
      before do
        write_configuration
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS

        write_file('frontend/javascripts/packages/my_package/owned_file.jsx', <<~CONTENTS)
          // @team Bar
        CONTENTS
      end

      it 'can find the owner of a javascript file with file annotations' do
        expect(CodeOwnership.for_file('frontend/javascripts/packages/my_package/owned_file.jsx').name).to eq 'Bar'
      end
    end

    context 'with javascript owned file with brackets' do
      before do
        write_configuration
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS

        write_file('frontend/javascripts/packages/my_package/[formID]/owned_file.jsx', <<~CONTENTS)
          // @team Bar
        CONTENTS
      end

      it 'can find the owner of a javascript file with file annotations' do
        expect(CodeOwnership.for_file('frontend/javascripts/packages/my_package/[formID]/owned_file.jsx').name).to eq 'Bar'
      end
    end

    context 'with haml owned file' do
      before do
        write_configuration
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS

        write_file('packs/my_pack/owned_file.html.haml', <<~CONTENTS)
          -# @team Bar
        CONTENTS
      end

      it 'can find the owner of a haml file with file annotations' do
        expect(CodeOwnership.for_file('packs/my_pack/owned_file.html.haml').name).to eq 'Bar'
      end
    end
  end

  describe '.remove_file_annotation!' do
    subject(:remove_file_annotation) do
      CodeOwnership.remove_file_annotation!(filename)
      # Getting the owner gets stored in the cache, so after we remove the file annotation we want to bust the cache
      CodeOwnership.bust_caches!
    end

    before do
      write_file('config/teams/foo.yml', <<~CONTENTS)
        name: Foo
      CONTENTS
      write_configuration
    end

    context 'when ruby file has no annotation' do
      let(:filename) { 'app/my_file.rb' }

      before do
        write_file(filename, <<~CONTENTS)
          # Empty file
        CONTENTS
      end

      it 'has no effect' do
        expect(File.read(filename)).to eq "# Empty file\n"

        remove_file_annotation

        expect(File.read(filename)).to eq "# Empty file\n"
      end
    end

    context 'when ruby file has annotation' do
      let(:filename) { 'app/my_file.rb' }

      before do
        write_file(filename, <<~CONTENTS)
          # @team Foo

          # Some content
        CONTENTS

        write_file('package.yml', <<~CONTENTS)
          enforce_dependency: true
          enforce_privacy: true
        CONTENTS
      end

      it 'removes the annotation' do
        current_ownership = CodeOwnership.for_file(filename)
        expect(current_ownership&.name).to eq 'Foo'
        expect(File.read(filename)).to eq <<~RUBY
          # @team Foo

          # Some content
        RUBY

        remove_file_annotation

        new_ownership = CodeOwnership.for_file(filename)
        expect(new_ownership).to be_nil
        expected_output = <<~RUBY
          # Some content
        RUBY

        expect(File.read(filename)).to eq expected_output
      end
    end

    context 'when javascript file has annotation' do
      let(:filename) { 'app/my_file.jsx' }

      before do
        write_file(filename, <<~CONTENTS)
          // @team Foo

          // Some content
        CONTENTS

        write_file('package.yml', <<~CONTENTS)
          enforce_dependency: true
          enforce_privacy: true
        CONTENTS
      end

      it 'removes the annotation' do
        current_ownership = CodeOwnership.for_file(filename)
        expect(current_ownership&.name).to eq 'Foo'
        expect(File.read(filename)).to eq <<~JAVASCRIPT
          // @team Foo

          // Some content
        JAVASCRIPT

        remove_file_annotation

        new_ownership = CodeOwnership.for_file(filename)
        expect(new_ownership).to be_nil
        expected_output = <<~JAVASCRIPT
          // Some content
        JAVASCRIPT

        expect(File.read(filename)).to eq expected_output
      end
    end

    context 'when haml has annotation' do
      let(:filename) { 'app.my_file.html.haml' }

      before do
        write_file(filename, <<~CONTENTS)
          -# @team Foo

          -# Some content
        CONTENTS

        write_file('package.yml', <<~CONTENTS)
          enforce_dependency: true
          enforce_privacy: true
        CONTENTS
      end

      it 'removes the annotation' do
        current_ownership = CodeOwnership.for_file(filename)
        expect(current_ownership&.name).to eq 'Foo'
        expect(File.read(filename)).to eq <<~HAML
          -# @team Foo

          -# Some content
        HAML

        remove_file_annotation

        new_ownership = CodeOwnership.for_file(filename)
        expect(new_ownership).to be_nil
        expected_output = <<~HAML
          -# Some content
        HAML

        expect(File.read(filename)).to eq expected_output
      end
    end

    context 'when file has new lines after the annotation' do
      let(:filename) { 'app/my_file.rb' }

      before do
        write_file(filename, <<~CONTENTS)
          # @team Foo


          # Some content


          # Some other content
        CONTENTS
      end

      it 'removes the annotation and the leading new lines' do
        expect(File.read(filename)).to eq <<~RUBY
          # @team Foo


          # Some content


          # Some other content
        RUBY

        remove_file_annotation

        expected_output = <<~RUBY
          # Some content


          # Some other content
        RUBY

        expect(File.read(filename)).to eq expected_output
      end
    end
  end
end
