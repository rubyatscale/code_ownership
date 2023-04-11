module CodeOwnership
  # We do not bust the cache here so that we only load the extension once!
  RSpec.describe Private::ExtensionLoader, :do_not_bust_cache do
    let(:codeowners_validation) { Private::Validations::GithubCodeownersUpToDate }

    before do
      write_configuration('require' => ['./lib/my_extension.rb'])

      write_file('config/teams/bar.yml', <<~CONTENTS)
        name: Bar
        github:
          team: '@org/my-team'
      CONTENTS

      write_file('app/services/my_ownable_file.rb')

      write_file('lib/my_extension.rb', <<~RUBY)
        class MyExtension
          extend T::Sig
          include CodeOwnership::Mapper
          include CodeOwnership::Validator
          
          sig do
            override.
              params(files: T::Array[String]).
              returns(T::Hash[String, T.nilable(::CodeTeams::Team)])
          end
          def map_files_to_owners(files) # rubocop:disable Lint/UnusedMethodArgument
            files.select{|f| Pathname.new(f).extname == '.rb'}.map{|f| [f, CodeTeams.all.last]}.to_h
          end

          sig do
            override.params(file: String).
              returns(T.nilable(::CodeTeams::Team))
          end
          def map_file_to_owner(file)
            CodeTeams.all.last
          end

          sig do
            override.returns(T::Hash[String, T.nilable(::CodeTeams::Team)])
          end
          def codeowners_lines_to_owners
            Dir.glob('**/*.rb').map{|f| [f, CodeTeams.all.last]}.to_h
          end

          sig { override.returns(String) }
          def description
            'My special extension'
          end

          sig { override.params(files: T::Array[String], autocorrect: T::Boolean, stage_changes: T::Boolean).returns(T::Array[String]) }
          def validation_errors(files:, autocorrect: true, stage_changes: true)
            ['my validation errors']
          end

          sig { override.void }
          def bust_caches!
            nil
          end
        end
      RUBY

      expect_any_instance_of(codeowners_validation).to receive(:`).with("git add #{codeowners_path}") # rubocop:disable RSpec/AnyInstance
    end

    after(:all) do
      validators_without_extension = Validator.instance_variable_get(:@validators).reject{|v| v == MyExtension }
      Validator.instance_variable_set(:@validators, validators_without_extension)
      mappers_without_extension = Mapper.instance_variable_get(:@mappers).reject{|v| v == MyExtension }
      Mapper.instance_variable_set(:@mappers, mappers_without_extension)        
    end

    describe 'CodeOwnership.validate!' do
      it 'allows third party validations to be injected' do
        expect { CodeOwnership.validate! }.to raise_error do |e|
          expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
          expect(e.message).to eq <<~EXPECTED.chomp
            my validation errors
            See https://github.com/rubyatscale/code_ownership#README.md for more details
          EXPECTED
        end
      end

      it 'allows extensions to add to codeowners list' do
        expect { CodeOwnership.validate! }.to raise_error(CodeOwnership::InvalidCodeOwnershipConfigurationError)
        expect(codeowners_path.read).to eq <<~EXPECTED
          # STOP! - DO NOT EDIT THIS FILE MANUALLY
          # This file was automatically generated by "bin/codeownership validate".
          #
          # CODEOWNERS is used for GitHub to suggest code/file owners to various GitHub
          # teams. This is useful when developers create Pull Requests since the
          # code/file owner is notified. Reference GitHub docs for more details:
          # https://help.github.com/en/articles/about-code-owners


          # Team YML ownership
          /config/teams/bar.yml @org/my-team

          # My special extension
          /app/services/my_ownable_file.rb @org/my-team
          /lib/my_extension.rb @org/my-team
        EXPECTED
      end
    end
  end
end
