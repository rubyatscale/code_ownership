# frozen_string_literal: true

# typed: strict

require 'set'
require 'code_teams'
require 'sorbet-runtime'
require 'json'
require 'packs'
require 'code_ownership/cli'
require 'code_ownership/private'

module CodeOwnership
  extend self
  extend T::Sig
  extend T::Helpers

  requires_ancestor { Kernel }

  sig { params(file: String).returns(T.nilable(CodeTeams::Team)) }
  def for_file(file)
    @for_file ||= T.let(@for_file, T.nilable(T::Hash[String, T.nilable(CodeTeams::Team)]))
    @for_file ||= {}

    return nil if file.start_with?('./')
    return @for_file[file] if @for_file.key?(file)

    owner = T.let(nil, T.nilable(CodeTeams::Team))

    Private.mappers.each do |mapper|
      owner = mapper.map_file_to_owner(file)
      break if owner
    end

    @for_file[file] = owner
  end

  sig { params(team: T.any(CodeTeams::Team, String)).returns(String) }
  def for_team(team)
    team = T.must(CodeTeams.find(team)) if team.is_a?(String)
    ownership_information = T.let([], T::Array[String])

    ownership_information << "# Code Ownership Report for `#{team.name}` Team"
    Private.mappers.each do |mapper|
      ownership_information << "## #{mapper.description}"
      codeowners_lines = mapper.codeowners_lines_to_owners
      ownership_for_mapper = []
      codeowners_lines.each do |line, team_for_line|
        next if team_for_line.nil?
        if team_for_line.name == team.name
          ownership_for_mapper << "- #{line}"
        end
      end

      if ownership_for_mapper.empty?
        ownership_information << 'This team owns nothing in this category.'
      else
        ownership_information += ownership_for_mapper
      end

      
      ownership_information << ""
    end

    ownership_information.join("\n")
  end

  class InvalidCodeOwnershipConfigurationError < StandardError
  end

  sig { params(filename: String).void }
  def self.remove_file_annotation!(filename)
    Private.file_annotations_mapper.remove_file_annotation!(filename)
  end

  sig do
    params(
      files: T::Array[String],
      autocorrect: T::Boolean,
      stage_changes: T::Boolean
    ).void
  end
  def validate!(
    files: Private.tracked_files,
    autocorrect: true,
    stage_changes: true
  )
    tracked_file_subset = Private.tracked_files & files
    Private.validate!(files: tracked_file_subset, autocorrect: autocorrect, stage_changes: stage_changes)
  end

  # Given a backtrace from either `Exception#backtrace` or `caller`, find the
  # first line that corresponds to a file with assigned ownership
  sig { params(backtrace: T.nilable(T::Array[String]), excluded_teams: T::Array[::CodeTeams::Team]).returns(T.nilable(::CodeTeams::Team)) }
  def for_backtrace(backtrace, excluded_teams: [])
    return unless backtrace

    backtrace_with_ownership(backtrace).find do |(team, _file)|
      team && !excluded_teams.include?(team)
    end&.first
  end

  sig { params(backtrace: T.nilable(T::Array[String])).returns(T::Array[[T.nilable(::CodeTeams::Team), String]]) }
  def backtrace_with_ownership(backtrace)
    return [] unless backtrace

    # The pattern for a backtrace hasn't changed in forever and is considered
    # stable: https://github.com/ruby/ruby/blob/trunk/vm_backtrace.c#L303-L317
    #
    # This pattern matches a line like the following:
    #
    #   ./app/controllers/some_controller.rb:43:in `block (3 levels) in create'
    #
    backtrace_line = %r{\A(#{Pathname.pwd}/|\./)?
        (?<file>.+)       # Matches 'app/controllers/some_controller.rb'
        :
        (?<line>\d+)      # Matches '43'
        :in\s
        `(?<function>.*)' # Matches "`block (3 levels) in create'"
      \z}x

    backtrace.filter_map do |line|
      match = line.match(backtrace_line)
      next unless match

      [
        CodeOwnership.for_file(T.must(match[:file])),
        match[:file],
      ]
    end
  end

  sig { params(klass: T.nilable(T.any(Class, Module))).returns(T.nilable(::CodeTeams::Team)) }
  def for_class(klass)
    @memoized_values ||= T.let(@memoized_values, T.nilable(T::Hash[String, T.nilable(::CodeTeams::Team)]))
    @memoized_values ||= {}
    # We use key because the memoized value could be `nil`
    if !@memoized_values.key?(klass.to_s)
      path = Private.path_from_klass(klass)
      return nil if path.nil?

      value_to_memoize = for_file(path)
      @memoized_values[klass.to_s] = value_to_memoize
      value_to_memoize
    else
      @memoized_values[klass.to_s]
    end
  end

  sig { params(package: Packs::Pack).returns(T.nilable(::CodeTeams::Team)) }
  def for_package(package)
    Private::OwnershipMappers::PackageOwnership.new.owner_for_package(package)
  end

  # Generally, you should not ever need to do this, because once your ruby process loads, cached content should not change.
  # Namely, the set of files, packages, and directories which are tracked for ownership should not change.
  # The primary reason this is helpful is for clients of CodeOwnership who want to test their code, and each test context
  # has different ownership and tracked files.
  sig { void }
  def self.bust_caches!
    @for_file = nil
    @memoized_values = nil
    Private.bust_caches!
    Private.mappers.each(&:bust_caches!)
  end
end
