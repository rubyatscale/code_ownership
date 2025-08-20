# typed: true

require 'optparse'
require 'pathname'
require 'fileutils'

module CodeOwnership
  class Cli
    EXECUTABLE = 'bin/codeownership'.freeze

    def self.run!(argv)
      command = argv.shift
      if command == 'validate'
        validate!(argv)
      elsif command == 'for_file'
        for_file(argv)
      elsif command == 'for_team'
        for_team(argv)
      elsif command == 'version'
        version
      elsif [nil, 'help'].include?(command)
        puts <<~USAGE
          Usage: #{EXECUTABLE} <subcommand>

          Subcommands:
            validate - run all validations
            for_file - find code ownership for a single file
            for_team - find code ownership information for a team
            help  - display help information about code_ownership
        USAGE
      else
        puts "'#{command}' is not a code_ownership command. See `#{EXECUTABLE} help`."
      end
    end

    def self.validate!(argv)
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{EXECUTABLE} validate [options]"

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
      args = parser.order!(argv)
      parser.parse!(args)

      files = if options[:diff]
                ENV.fetch('CODEOWNERS_GIT_STAGED_FILES') { `git diff --staged --name-only` }.split("\n").select do |file|
                  File.exist?(file)
                end
              else
                nil
              end

      CodeOwnership.validate!(
        files: files,
        autocorrect: !options[:skip_autocorrect],
        stage_changes: !options[:skip_stage]
      )
    end

    def self.version
      puts CodeOwnership.version.join("\n")
    end

    # For now, this just returns team ownership
    # Later, this could also return code ownership errors about that file.
    def self.for_file(argv)
      options = {}

      # Long-term, we probably want to use something like `thor` so we don't have to implement logic
      # like this. In the short-term, this is a simple way for us to use the built-in OptionParser
      # while having an ergonomic CLI.
      files = argv.reject { |arg| arg.start_with?('--') }

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{EXECUTABLE} for_file [options]"

        opts.on('--json', 'Output as JSON') do
          options[:json] = true
        end

        opts.on('--verbose', 'Output verbose information') do
          options[:verbose] = true
        end

        opts.on('--help', 'Shows this prompt') do
          puts opts
          exit
        end
      end
      args = parser.order!(argv)
      parser.parse!(args)

      if files.count != 1
        raise "Please pass in one file. Use `#{EXECUTABLE} for_file --help` for more info"
      end

      if options[:verbose]
        do_for_file_verbose(file: files.first, json: options[:json])
      else
        do_for_file(file: files.first, json: options[:json])
      end
    end

    def self.do_for_file_verbose(file:, json:)
      verbose = CodeOwnership.for_file_verbose(file)
      name = (verbose&[:name] || 'Unowned')
      config_yml = (verbose&[:config_yml] || 'Unowned'
      reasons = (verbose&[:reasons] || ''

      if json
        json = {
          name: name,
          config_yml: config_yml,
          reasons: reasons
        }

        puts json.to_json
      else
        puts <<~MSG
          Team: #{verbose_name}
          Team YML: #{verbose_yml}
          Reasons: "\n#{reasons.join("\n-")}"
        MSG
      end
    end

    def self.do_for_file(file:, json:)
      team = CodeOwnership.for_file(file)
      team_name = team&.name || 'Unowned'
      team_yml = team&.config_yml || 'Unowned'

      if json
        json = {
          team_name: team_name,
          team_yml: team_yml
        }

        puts json.to_json
      else
        puts <<~MSG
          Team: #{team_name}
          Team YML: #{team_yml}
        MSG
      end
    end

    def self.for_team(argv)
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{EXECUTABLE} for_team 'Team Name'"

        opts.on('--help', 'Shows this prompt') do
          puts opts
          exit
        end
      end
      teams = argv.reject { |arg| arg.start_with?('--') }
      args = parser.order!(argv)
      parser.parse!(args)

      if teams.count != 1
        raise "Please pass in one team. Use `#{EXECUTABLE} for_team --help` for more info"
      end

      puts CodeOwnership.for_team(teams.first).join("\n")
    end
  end
end
