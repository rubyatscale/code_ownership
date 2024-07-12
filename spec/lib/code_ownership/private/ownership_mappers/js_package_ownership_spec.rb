module CodeOwnership
  RSpec.describe Private::OwnershipMappers::JsPackageOwnership do
    describe 'CodeOwnership.validate!' do
      context 'application has invalid JSON in package' do
        before do
          write_configuration

          write_file('frontend/javascripts/my_package/package.json', <<~CONTENTS)
            { syntax error!!!
              "metadata": {
                "owner": "Foo"
              }
            }
          CONTENTS
        end

        it 'lets the user know the their package JSON is invalid' do
          expect { CodeOwnership.validate! }.to raise_error do |e|
            expect(e).to be_a CodeOwnership::InvalidCodeOwnershipConfigurationError
            expect(e.message).to match(/JSON::ParserError.*?unexpected token/)
            expect(e.message).to include 'frontend/javascripts/my_package/package.json has invalid JSON, so code ownership cannot be determined.'
            expect(e.message).to include 'Please either make the JSON in that file valid or specify `js_package_paths` in config/code_ownership.yml.'
          end
        end
      end
    end

    describe 'CodeOwnershp.for_file' do
      before do
        write_configuration

        write_file('frontend/javascripts/packages/my_other_package/package.json', <<~CONTENTS)
          {
            "name": "@gusto/my_package",
            "metadata": {
              "owner": "Bar"
            }
          }
        CONTENTS
        write_file('frontend/javascripts/packages/my_other_package/my_file.jsx')
        write_file('frontend/javascripts/packages/different_package/test/my_file.ts', <<~CONTENTS)
          // @team Bar
        CONTENTS
        write_file('frontend/javascripts/packages/different_package/[test]/my_file.ts', <<~CONTENTS)
          // @team Bar
        CONTENTS
        write_file('config/teams/bar.yml', <<~CONTENTS)
          name: Bar
        CONTENTS
      end

      it 'can find the owner of files in team-owned javascript packages' do
        expect(CodeOwnership.for_file('frontend/javascripts/packages/my_other_package/my_file.jsx').name).to eq 'Bar'
        expect(CodeOwnership.for_file('frontend/javascripts/packages/different_package/[test]/my_file.ts').name).to eq 'Bar'
      end
    end
  end
end
