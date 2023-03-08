module CodeOwnership
  RSpec.describe Private::OwnershipMappers::JsPackageOwnership do
    describe 'CodeOwnership.validate!' do
      context 'application has invalid JSON in package' do
        before do
          write_file('config/code_ownership.yml', {}.to_yaml)

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
            expect(e.message).to match /JSON::ParserError.*?unexpected token/
            expect(e.message).to include 'frontend/javascripts/my_package/package.json has invalid JSON, so code ownership cannot be determined.'
            expect(e.message).to include 'Please either make the JSON in that file valid or specify `js_package_paths` in config/code_ownership.yml.'
          end
        end
      end
    end
  end
end
