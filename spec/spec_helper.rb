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

  config.include_context 'application fixtures'

  config.before do |c|
    unless c.metadata[:do_not_bust_cache]
      CodeOwnership.bust_caches!
      CodeTeams.bust_caches!
      allow(CodeTeams::Plugin).to receive(:registry).and_return({})
    end
  end

  config.around do |example|
    if example.metadata[:skip_chdir_to_tmpdir]
      example.run
    else
      begin
        prefix = [File.basename($0), Process.pid].join('-') # rubocop:disable Style/SpecialGlobalVars
        tmpdir = Dir.mktmpdir(prefix)
        Dir.chdir(tmpdir) do
          example.run
        end
      ensure
        FileUtils.rm_rf(tmpdir)
      end
    end
  end
end
