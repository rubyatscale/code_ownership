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

  sig { returns(T::Array[String]) }
  def version
    ["code_ownership version: #{VERSION}",
     "codeowners-rs version: #{::RustCodeOwners.version}"]
  end

  # Returns the team that owns the given file based on the CODEOWNERS file.
  # This is much faster and can be safely used when the CODEOWNERS files is up to date.
  # Examples of reliable usage:
  # - running in CI pipeline
  # - running on the server
  # Examples of unreliable usage:
  # - running in IDE when files are changing and the CODEOWNERS file is not getting updated
  sig { params(file: String).returns(T.nilable(CodeTeams::Team)) }
  def for_file_from_codeowners(file)
    teams_for_files_from_codeowners([file]).values.first
  end

  sig { params(file: String).returns(T.nilable(CodeTeams::Team)) }
  def for_file(file)
    Private::TeamFinder.for_file(file)
  end

  sig { params(files: T::Array[String]).returns(T::Hash[String, T.nilable(CodeTeams::Team)]) }
  def teams_for_files_from_codeowners(files)
    Private::TeamFinder.teams_for_files(files)
  end

  sig { params(file: String).returns(T.nilable(T::Hash[Symbol, String])) }
  def for_file_verbose(file)
    ::RustCodeOwners.for_file(file)
  end

  sig { params(team: T.any(CodeTeams::Team, String)).returns(T::Array[String]) }
  def for_team(team)
    team = T.must(CodeTeams.find(team)) if team.is_a?(String)
    ::RustCodeOwners.for_team(team.name)
  end

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
      ::RustCodeOwners.generate_and_validate(!stage_changes)
    else
      ::RustCodeOwners.validate
    end
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
