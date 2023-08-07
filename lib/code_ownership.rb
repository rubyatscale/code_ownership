# frozen_string_literal: true

# typed: strict

require 'set'
require 'code_teams'
require 'sorbet-runtime'
require 'json'
require 'packs'
require 'code_ownership/mapper'
require 'code_ownership/validator'
require 'code_ownership/private'
require 'code_ownership/cli'
require 'code_ownership/configuration'

if defined?(Packwerk)
  require 'code_ownership/private/permit_pack_owner_top_level_key'
end

module CodeOwnership
  extend self
  extend T::Sig
  extend T::Helpers

  requires_ancestor { Kernel }
  GlobsToOwningTeamMap = T.type_alias { T::Hash[String, CodeTeams::Team] }

  sig { params(file: String).returns(T.nilable(CodeTeams::Team)) }
  def for_file(file)
    @for_file ||= T.let(@for_file, T.nilable(T::Hash[String, T.nilable(CodeTeams::Team)]))
    @for_file ||= {}

    return nil if file.start_with?('./')
    return @for_file[file] if @for_file.key?(file)

    Private.load_configuration!

    owner = T.let(nil, T.nilable(CodeTeams::Team))

    Mapper.all.each do |mapper|
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

    Private.glob_cache.raw_cache_contents.each do |mapper_description, glob_to_owning_team_map|
      ownership_information << "## #{mapper_description}"
      ownership_for_mapper = []
      glob_to_owning_team_map.each do |glob, owning_team|
        next if owning_team != team
        ownership_for_mapper << "- #{glob}"
      end

      if ownership_for_mapper.empty?
        ownership_information << 'This team owns nothing in this category.'
      else
        ownership_information += ownership_for_mapper.sort
      end

      ownership_information << ""
    end

    ownership_information.join("\n")
  end

  class InvalidCodeOwnershipConfigurationError < StandardError
  end

  sig { params(filename: String).void }
  def self.remove_file_annotation!(filename)
    Private::OwnershipMappers::FileAnnotations.new.remove_file_annotation!(filename)
  end

  sig do
    params(
      autocorrect: T::Boolean,
      stage_changes: T::Boolean,
      files: T.nilable(T::Array[String]),
    ).void
  end
  def validate!(
    autocorrect: true,
    stage_changes: true,
    files: nil
  )
    Private.load_configuration!

    tracked_file_subset = if files
      files.select{|f| Private.file_tracked?(f)}
    else
      Private.tracked_files
    end

    Private.validate!(files: tracked_file_subset, autocorrect: autocorrect, stage_changes: stage_changes)
  end

  # Given a backtrace from either `Exception#backtrace` or `caller`, find the
  # first line that corresponds to a file with assigned ownership
  sig { params(backtrace: T.nilable(T::Array[String]), excluded_teams: T::Array[::CodeTeams::Team]).returns(T.nilable(::CodeTeams::Team)) }
  def for_backtrace(backtrace, excluded_teams: [])
    first_owned_file_for_backtrace(backtrace, excluded_teams: excluded_teams)&.first
  end

  # Given a backtrace from either `Exception#backtrace` or `caller`, find the
  # first owned file in it, useful for figuring out which file is being blamed.
  sig { params(backtrace: T.nilable(T::Array[String]), excluded_teams: T::Array[::CodeTeams::Team]).returns(T.nilable([::CodeTeams::Team, String])) }
  def first_owned_file_for_backtrace(backtrace, excluded_teams: [])
    backtrace_with_ownership(backtrace).each do |(team, file)|
      if team && !excluded_teams.include?(team)
        return [team, file]
      end
    end

    nil
  end

  sig { params(backtrace: T.nilable(T::Array[String])).returns(T::Enumerable[[T.nilable(::CodeTeams::Team), String]]) }
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

    backtrace.lazy.filter_map do |line|
      match = line.match(backtrace_line)
      next unless match

      file = T.must(match[:file])

      [
        CodeOwnership.for_file(file),
        file,
      ]
    end
  end
  private_class_method(:backtrace_with_ownership)

  sig { params(klass: T.nilable(T.any(T::Class[T.anything], Module))).returns(T.nilable(::CodeTeams::Team)) }
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
    Mapper.all.each(&:bust_caches!)
  end

  sig { returns(Configuration) }
  def self.configuration
    Private.configuration
  end
end
