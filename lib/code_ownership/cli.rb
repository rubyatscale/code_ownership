# typed: true

require 'optparse'
require 'pathname'

module CodeOwnership
  class Cli
    def self.run!(argv)
      # Someday we might support other subcommands. When we do that, we can call
      # argv.shift to get the first argument and check if it's a given subcommand.
      command = argv.shift
      if command == 'validate'
        validate!(argv)
      end
    end

    def self.validate!(argv)
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: bin/codeownership validate [options]'

        opts.on('--skip-autocorrect', 'Skip automatically correcting any errors, such as the .github/CODEOWNERS file') do
          options[:skip_autocorrect] = true
        end

        opts.on('-d', '--diff', 'Only run validations with staged files') do
          options[:diff] = true
        end

        opts.on('-s', '--skip-stage', 'Skips staging the CODEOWNERS file') do
          options[:skip_stage] = true
        end

        opts.on('--help', 'Shows this prompt') do
          puts opts
          exit
        end
      end
      args = parser.order!(argv) {}
      parser.parse!(args)

      files = if options[:diff]
        ENV.fetch('CODEOWNERS_GIT_STAGED_FILES') { `git diff --staged --name-only` }.split("\n").select do |file|
          File.exist?(file)
        end
      else
        Private.tracked_files
      end

      CodeOwnership.validate!(
        files: files,
        autocorrect: !options[:skip_autocorrect],
        stage_changes: !options[:skip_stage]
      )
    end

    private_class_method :validate!
  end
end
