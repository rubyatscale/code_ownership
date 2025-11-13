# frozen_string_literal: true

# typed: strict

require 'set'
require 'code_teams'
require 'sorbet-runtime'
require 'json'
require 'packs-specification'
require 'code_ownership/version'
require 'code_ownership/private/file_path_finder'
require 'code_ownership/private/file_path_team_cache'
require 'code_ownership/private/team_finder'
require 'code_ownership/private/for_file_output_builder'
require 'code_ownership/cli'

begin
  RUBY_VERSION =~ /(\d+\.\d+)/
  require "code_ownership/#{Regexp.last_match(1)}/code_ownership"
rescue LoadError
  require 'code_ownership/code_ownership'
end

if defined?(Packwerk)
  require 'code_ownership/private/permit_pack_owner_top_level_key'
end

module CodeOwnership
  module_function

  extend T::Sig
  extend T::Helpers

  requires_ancestor { Kernel }
  GlobsToOwningTeamMap = T.type_alias { T::Hash[String, CodeTeams::Team] }

  # Returns the version of the code_ownership gem and the codeowners-rs gem.
  sig { returns(T::Array[String]) }
  def version
    ["code_ownership version: #{VERSION}",
     "codeowners-rs version: #{::RustCodeOwners.version}"]
  end

  # Returns the owning team for a given file path.
  #
  # @param file [String] The path to the file to find ownership for. Can be relative or absolute.
  # @param from_codeowners [Boolean] (default: true) When true, uses CODEOWNERS file to determine ownership.
  #                                  When false, uses alternative team finding strategies (e.g., package ownership).
  #                                  from_codeowners true is faster because it simply matches the provided file to the generate CODEOWNERS file. This is a safe option when you can trust the CODEOWNERS file to be up to date.
  # @param allow_raise [Boolean] (default: false) When true, raises an exception if ownership cannot be determined.
  #                              When false, returns nil for files without ownership.
  #
  # @return [CodeTeams::Team, nil] The team that owns the file, or nil if no owner is found
  #                                 (unless allow_raise is true, in which case an exception is raised).
  #
  # @example Find owner for a file using CODEOWNERS
  #   team = CodeOwnership.for_file('app/models/user.rb')
  #   # => #<CodeTeams::Team:0x... @name="platform">
  #
  # @example Find owner without using CODEOWNERS
  #   team = CodeOwnership.for_file('app/models/user.rb', from_codeowners: false)
  #   # => #<CodeTeams::Team:0x... @name="platform">
  #
  # @example Raise if no owner is found
  #   team = CodeOwnership.for_file('unknown_file.rb', allow_raise: true)
  #   # => raises exception if no owner found
  #
  sig { params(file: String, from_codeowners: T::Boolean, allow_raise: T::Boolean).returns(T.nilable(CodeTeams::Team)) }
  def for_file(file, from_codeowners: true, allow_raise: false)
    if from_codeowners
      teams_for_files_from_codeowners([file], allow_raise: allow_raise).values.first
    else
      Private::TeamFinder.for_file(file, allow_raise: allow_raise)
    end
  end

  # Returns the owning teams for multiple file paths using the CODEOWNERS file.
  #
  # This method efficiently determines ownership for multiple files in a single operation
  # by leveraging the generated CODEOWNERS file. It's more performant than calling
  # `for_file` multiple times when you need to check ownership for many files.
  #
  # @param files [Array<String>] An array of file paths to find ownership for.
  #                               Paths can be relative to the project root or absolute.
  # @param allow_raise [Boolean] (default: false) When true, raises an exception if a team
  #                              name in CODEOWNERS cannot be resolved to an actual team.
  #                              When false, returns nil for files with unresolvable teams.
  #
  # @return [T::Hash[String, T.nilable(CodeTeams::Team)]] A hash mapping each file path to its
  #                                                 owning team. Files without ownership
  #                                                 or with unresolvable teams will map to nil.
  #
  # @example Get owners for multiple files
  #   files = ['app/models/user.rb', 'app/controllers/users_controller.rb', 'config/routes.rb']
  #   owners = CodeOwnership.teams_for_files_from_codeowners(files)
  #   # => {
  #   #   'app/models/user.rb' => #<CodeTeams::Team:0x... @name="platform">,
  #   #   'app/controllers/users_controller.rb' => #<CodeTeams::Team:0x... @name="platform">,
  #   #   'config/routes.rb' => #<CodeTeams::Team:0x... @name="infrastructure">
  #   # }
  #
  # @example Handle files without owners
  #   files = ['owned_file.rb', 'unowned_file.txt']
  #   owners = CodeOwnership.teams_for_files_from_codeowners(files)
  #   # => {
  #   #   'owned_file.rb' => #<CodeTeams::Team:0x... @name="backend">,
  #   #   'unowned_file.txt' => nil
  #   # }
  #
  # @note This method uses caching internally for performance. The cache is populated
  #       as files are processed and reused for subsequent lookups.
  #
  # @note This method relies on the CODEOWNERS file being up-to-date. Run
  #       `CodeOwnership.validate!` to ensure the CODEOWNERS file is current.
  #
  # @see #for_file for single file ownership lookup
  # @see #validate! for ensuring CODEOWNERS file is up-to-date
  #
  sig { params(files: T::Array[String], allow_raise: T::Boolean).returns(T::Hash[String, T.nilable(CodeTeams::Team)]) }
  def teams_for_files_from_codeowners(files, allow_raise: false)
    Private::TeamFinder.teams_for_files(files, allow_raise: allow_raise)
  end

  # Returns detailed ownership information for a given file path.
  #
  # This method provides verbose ownership details including the team name,
  # team configuration file path, and the reasons/sources for ownership assignment.
  # It's particularly useful for debugging ownership assignments and understanding
  # why a file is owned by a specific team.
  #
  # @param file [String] The path to the file to find ownership for. Can be relative or absolute.
  #
  # @return [T::Hash[Symbol, String], nil] A hash containing detailed ownership information,
  #                                         or nil if no owner is found.
  #
  # The returned hash contains the following keys when an owner is found:
  # - :team_name [String] - The name of the owning team
  # - :team_config_yml [String] - Path to the team's configuration YAML file
  # - :reasons [Array<String>] - List of reasons/sources explaining why this team owns the file
  #                               (e.g., "CODEOWNERS pattern: /app/models/**", "Package ownership")
  #
  # @example Get verbose ownership details
  #   details = CodeOwnership.for_file_verbose('app/models/user.rb')
  #   # => {
  #   #   team_name: "platform",
  #   #   team_config_yml: "config/teams/platform.yml",
  #   #   reasons: ["Matched pattern '/app/models/**' in CODEOWNERS"]
  #   # }
  #
  # @example Handle unowned files
  #   details = CodeOwnership.for_file_verbose('unowned_file.txt')
  #   # => nil
  #
  # @note This method is primarily used by the CLI tool when the --verbose flag is provided,
  #       allowing users to understand the ownership assignment logic.
  #
  # @note Unlike `for_file`, this method always uses the CODEOWNERS file and other ownership
  #       sources to determine ownership, providing complete context about the ownership decision.
  #
  # @see #for_file for a simpler ownership lookup that returns just the team
  # @see CLI#for_file for the command-line interface that uses this method
  #
  sig { params(file: String).returns(T.nilable(T::Hash[Symbol, String])) }
  def for_file_verbose(file)
    ::RustCodeOwners.for_file(file)
  end

  sig { params(team: T.any(CodeTeams::Team, String)).returns(T::Array[String]) }
  def for_team(team)
    team = T.must(CodeTeams.find(team)) if team.is_a?(String)
    ::RustCodeOwners.for_team(team.name)
  end

  # Validates code ownership configuration and optionally corrects issues.
  #
  # This method performs comprehensive validation of the code ownership setup, ensuring:
  # 1. Only one ownership mechanism is defined per file (no conflicts between annotations, packages, or globs)
  # 2. All referenced teams are valid (exist in CodeTeams configuration)
  # 3. All files have ownership (unless explicitly listed in unowned_globs)
  # 4. The .github/CODEOWNERS file is up-to-date and properly formatted
  #
  # When autocorrect is enabled, the method will automatically:
  # - Generate or update the CODEOWNERS file based on current ownership rules
  # - Fix any formatting issues in the CODEOWNERS file
  # - Stage the corrected CODEOWNERS file (unless stage_changes is false)
  #
  # @param autocorrect [Boolean] Whether to automatically fix correctable issues (default: true)
  #                              When true, regenerates and updates the CODEOWNERS file
  #                              When false, only validates without making changes
  #
  # @param stage_changes [Boolean] Whether to stage the CODEOWNERS file after autocorrection (default: true)
  #                                Only applies when autocorrect is true
  #                                When false, changes are written but not staged with git
  #
  # @param files [Array<String>, nil] Ignored. This is a legacy parameter that is no longer used.
  #
  # @return [void]
  #
  # @raise [RuntimeError] Raises an error if validation fails with details about:
  #                       - Files with conflicting ownership definitions
  #                       - References to non-existent teams
  #                       - Files without ownership (not in unowned_globs)
  #                       - CODEOWNERS file inconsistencies
  #
  # @example Basic validation with autocorrection
  #   CodeOwnership.validate!
  #   # Validates all files and auto-corrects/stages CODEOWNERS if needed
  #
  # @example Validation without making changes
  #   CodeOwnership.validate!(autocorrect: false)
  #   # Only checks for issues without updating CODEOWNERS
  #
  # @example Validate and fix but don't stage changes
  #   CodeOwnership.validate!(autocorrect: true, stage_changes: false)
  #   # Fixes CODEOWNERS but doesn't stage it with git
  #
  # @note This method is called by the CLI command: bin/codeownership validate
  # @note The validation can be disabled for CODEOWNERS by setting skip_codeowners_validation: true in config/code_ownership.yml
  #
  # @see CLI.validate! for the command-line interface
  # @see https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners for CODEOWNERS format
  #
  sig do
    params(
      autocorrect: T::Boolean,
      stage_changes: T::Boolean,
      files: T.nilable(T::Array[String])
    ).void
  end
  def validate!(
    autocorrect: true,
    stage_changes: true,
    files: nil
  )
    if autocorrect
      ::RustCodeOwners.generate_and_validate(files, !stage_changes)
    else
      ::RustCodeOwners.validate(files)
    end
  end

  # Removes the file annotation (e.g., "# @team TeamName") from a file.
  #
  # This method removes the ownership annotation from the first line of a file,
  # which is typically used to declare team ownership at the file level.
  # The annotation can be in the form of:
  # - Ruby comments: # @team TeamName
  # - JavaScript/TypeScript comments: // @team TeamName
  # - YAML comments: -# @team TeamName
  #
  # If the file does not have an annotation or the annotation doesn't match a valid team,
  # this method does nothing.
  #
  # @param filename [String] The path to the file from which to remove the annotation.
  #                          Can be relative or absolute.
  #
  # @return [void]
  #
  # @example Remove annotation from a Ruby file
  #   # Before: File contains "# @team Platform\nclass User; end"
  #   CodeOwnership.remove_file_annotation!('app/models/user.rb')
  #   # After: File contains "class User; end"
  #
  # @example Remove annotation from a JavaScript file
  #   # Before: File contains "// @team Frontend\nexport default function() {}"
  #   CodeOwnership.remove_file_annotation!('app/javascript/component.js')
  #   # After: File contains "export default function() {}"
  #
  # @note This method modifies the file in place.
  # @note Leading newlines after the annotation are also removed to maintain clean formatting.
  #
  sig { params(filename: String).void }
  def remove_file_annotation!(filename)
    filepath = Pathname.new(filename)

    begin
      content = filepath.read
    rescue Errno::EISDIR, Errno::ENOENT
      # Ignore files that fail to read (directories, missing files, etc.)
      return
    end

    # Remove the team annotation and any trailing newlines after it
    team_pattern = %r{\A(?:#|//|-#) @team .*\n+}
    new_content = content.sub(team_pattern, '')

    filepath.write(new_content) if new_content != content
  rescue ArgumentError => e
    # Handle invalid byte sequences gracefully
    raise unless e.message.include?('invalid byte sequence')
  end

  # Given a backtrace from either `Exception#backtrace` or `caller`, find the
  # first line that corresponds to a file with assigned ownership
  sig { params(backtrace: T.nilable(T::Array[String]), excluded_teams: T::Array[::CodeTeams::Team]).returns(T.nilable(::CodeTeams::Team)) }
  def for_backtrace(backtrace, excluded_teams: [])
    Private::TeamFinder.for_backtrace(backtrace, excluded_teams: excluded_teams)
  end

  # Given a backtrace from either `Exception#backtrace` or `caller`, find the
  # first owned file in it, useful for figuring out which file is being blamed.
  sig { params(backtrace: T.nilable(T::Array[String]), excluded_teams: T::Array[::CodeTeams::Team]).returns(T.nilable([::CodeTeams::Team, String])) }
  def first_owned_file_for_backtrace(backtrace, excluded_teams: [])
    Private::TeamFinder.first_owned_file_for_backtrace(backtrace, excluded_teams: excluded_teams)
  end

  sig { params(klass: T.nilable(T.any(T::Class[T.anything], Module))).returns(T.nilable(::CodeTeams::Team)) }
  def for_class(klass)
    Private::TeamFinder.for_class(klass)
  end

  sig { params(package: Packs::Pack).returns(T.nilable(::CodeTeams::Team)) }
  def for_package(package)
    Private::TeamFinder.for_package(package)
  end

  # Generally, you should not ever need to do this, because once your ruby process loads, cached content should not change.
  # Namely, the set of files, packages, and directories which are tracked for ownership should not change.
  # The primary reason this is helpful is for clients of CodeOwnership who want to test their code, and each test context
  # has different ownership and tracked files.
  sig { void }
  def self.bust_caches!
    Private::FilePathTeamCache.bust_cache!
  end
end
