RSpec.shared_context 'application fixtures' do
  let(:codeowners_path) { Pathname.pwd.join('.github/CODEOWNERS') }

  def write_configuration(owned_globs: nil, **kwargs)
    owned_globs ||= ['{app,components,config,frontend,lib,packs,spec}/**/*.{rb,rake,js,jsx,ts,tsx,json,yml}']
    config = {
      'owned_globs' => owned_globs,
      'unowned_globs' => ['config/code_ownership.yml']
    }.merge(kwargs)
    write_file('config/code_ownership.yml', config.to_yaml)
  end

  def write_file(path, content = '')
    pathname = Pathname.pwd.join(path)
    FileUtils.mkdir_p(pathname.dirname)
    pathname.write(content)
    path
  end

  let(:create_non_empty_application) do
    write_configuration

    write_file('frontend/javascripts/packages/my_package/owned_file.jsx', <<~CONTENTS)
      // @team Bar
    CONTENTS

    write_file('packs/my_pack/owned_file.rb', <<~CONTENTS)
      # @team Bar
      class OwnedFile; end
    CONTENTS

    write_file('directory/owner/.codeowner', <<~CONTENTS)
      Bar
    CONTENTS
    write_file('directory/owner/some_directory_file.ts')
    write_file('directory/owner/(my_folder)/.codeowner', <<~CONTENTS)
      Foo
    CONTENTS
    write_file('directory/owner/(my_folder)/some_other_file.ts')

    write_file('frontend/javascripts/packages/my_other_package/package.json', <<~CONTENTS)
      {
        "name": "@gusto/my_package",
        "metadata": {
          "owner": "Bar"
        }
      }
    CONTENTS
    write_file('frontend/javascripts/packages/my_other_package/my_file.jsx')

    write_file('config/teams/foo.yml', <<~CONTENTS)
      name: Foo
      github:
        team: '@MyOrg/foo-team'
    CONTENTS

    write_file('config/teams/bar.yml', <<~CONTENTS)
      name: Bar
      github:
        team: '@MyOrg/bar-team'
      owned_globs:
        - app/services/bar_stuff/**
        - frontend/javascripts/bar_stuff/**
    CONTENTS

    write_file('app/services/bar_stuff/thing.rb')
    write_file('frontend/javascripts/bar_stuff/thing.jsx')

    write_file('packs/my_other_package/package.yml', <<~CONTENTS)
      enforce_dependency: true
      enforce_privacy: true
      owner: Bar
    CONTENTS

    write_file('package.yml', <<~CONTENTS)
      enforce_dependency: true
      enforce_privacy: true
    CONTENTS

    write_file('packs/my_other_package/my_file.rb')
  end

  let(:create_files_with_defined_classes) do
    write_file('app/my_file.rb', <<~CONTENTS)
      # @team Foo

      require_relative 'my_error'

      class MyFile
        def self.raise_error
          MyError.raise_error
        end
      end
    CONTENTS

    write_file('app/my_error.rb', <<~CONTENTS)
      # @team Bar

      class MyError
        def self.raise_error
          raise "some error"
        end
      end
    CONTENTS

    write_file('config/teams/foo.yml', <<~CONTENTS)
      name: Foo
      github:
        team: '@MyOrg/foo-team'
    CONTENTS

    write_file('config/teams/bar.yml', <<~CONTENTS)
      name: Bar
      github:
        team: '@MyOrg/bar-team'
    CONTENTS

    # Some of the tests use the `SequoiaTree` constant. Since the implementation leverages:
    # `path = Object.const_source_location(klass.to_s)&.first`, we want to make sure that
    # we re-require the constant each time, since `RSpecTempfiles` changes where the file lives with each test
    Object.send(:remove_const, :MyFile) if defined? MyFile # :
    Object.send(:remove_const, :MyError) if defined? MyError # :
    require Pathname.pwd.join('app/my_file')
  end
end
