# frozen_string_literal: true

# typed: strict

require 'code_ownership/private/extension_loader'
require 'code_ownership/private/team_plugins/ownership'
require 'code_ownership/private/team_plugins/github'
require 'code_ownership/private/parse_js_packages'
require 'code_ownership/private/validations/files_have_owners'
require 'code_ownership/private/validations/github_codeowners_up_to_date'
require 'code_ownership/private/validations/files_have_unique_owners'
require 'code_ownership/private/ownership_mappers/file_annotations'
require 'code_ownership/private/ownership_mappers/team_globs'
require 'code_ownership/private/ownership_mappers/package_ownership'
require 'code_ownership/private/ownership_mappers/js_package_ownership'
require 'code_ownership/private/ownership_mappers/team_yml_ownership'

module CodeOwnership
  module Private
    extend T::Sig

    sig { returns(Configuration) }
    def self.configuration
      @configuration ||= T.let(@configuration, T.nilable(Configuration))
      @configuration ||= Configuration.fetch
    end

    # This is just an alias for `configuration` that makes it more explicit what we're doing instead of just calling `configuration`.
    # This is necessary because configuration may contain extensions of code ownership, so those extensions should be loaded prior to
    # calling APIs that provide ownership information.
    sig { returns(Configuration) }
    def self.load_configuration!
      configuration
    end

    sig { void }
    def self.bust_caches!
      @configuration = nil
      @tracked_files = nil
      @files_by_mapper = nil
    end

    sig { params(files: T::Array[String], autocorrect: T::Boolean, stage_changes: T::Boolean).void }
    def self.validate!(files:, autocorrect: true, stage_changes: true)
      errors = Validator.all.flat_map do |validator|
        validator.validation_errors(
          files: files,
          autocorrect: autocorrect,
          stage_changes: stage_changes
        )
      end

      if errors.any?
        errors << 'See https://github.com/rubyatscale/code_ownership#README.md for more details'
        raise InvalidCodeOwnershipConfigurationError.new(errors.join("\n")) # rubocop:disable Style/RaiseArgs
      end
    end

    # Returns a string version of the relative path to a Rails constant,
    # or nil if it can't find something
    sig { params(klass_string: T.nilable(String)).returns(T.nilable(String)) }
    def self.path_from_klass_string(klass_string)
      if klass_string
        path = Object.const_source_location(klass_string)&.first
        (path && Pathname.new(path).relative_path_from(Pathname.pwd).to_s) || nil
      else
        nil
      end
    end

    #
    # The output of this function is string pathnames relative to the root.
    #
    sig { returns(T::Array[String]) }
    def self.tracked_files
      @tracked_files ||= T.let(@tracked_files, T.nilable(T::Array[String]))
      @tracked_files ||= Dir.glob(configuration.owned_globs)
    end

    sig { params(team_name: String, location_of_reference: String).returns(CodeTeams::Team) }
    def self.find_team!(team_name, location_of_reference)
      found_team = CodeTeams.find(team_name)
      if found_team.nil?
        raise StandardError, "Could not find team with name: `#{team_name}` in #{location_of_reference}. Make sure the team is one of `#{CodeTeams.all.map(&:name).sort}`"
      else
        found_team
      end
    end

    sig { params(files: T::Array[String]).returns(T::Hash[String, T::Array[String]]) }
    def self.files_by_mapper(files)
      @files_by_mapper ||= T.let(@files_by_mapper, T.nilable(T::Hash[String, T::Array[String]]))
      @files_by_mapper ||= begin
        files_by_mapper = files.map { |file| [file, []] }.to_h

        Mapper.all.each do |mapper|
          mapper.map_files_to_owners(files).each do |file, _team|
            files_by_mapper[file] ||= []
            T.must(files_by_mapper[file]) << mapper.description
          end
        end

        files_by_mapper
      end
    end
  end

  private_constant :Private
end
