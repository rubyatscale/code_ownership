require 'bundler/setup'
require 'debug'
require 'packwerk'
require 'code_ownership'
require 'code_teams'
require 'packs/rspec/support'
require_relative 'support/application_fixtures'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include_context 'with application fixtures'

  config.before do |c|
    allow_any_instance_of(CodeOwnership.const_get(:Private)::Validations::GithubCodeownersUpToDate).to receive(:`)
    allow(CodeOwnership::Cli).to receive(:`)
    codeowners_path.delete if codeowners_path.exist?

    unless c.metadata[:do_not_bust_cache]
      CodeOwnership.bust_caches!
      CodeTeams.bust_caches!
      allow(CodeTeams::Plugin).to receive(:registry).and_return({})
    end
  end
end
