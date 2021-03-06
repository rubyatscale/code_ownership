# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `code_teams` gem.
# Please instead update this file by running `bin/tapioca gem code_teams`.

module CodeTeams
  class << self
    sig { returns(T::Array[::CodeTeams::Team]) }
    def all; end

    sig { void }
    def bust_caches!; end

    sig { params(name: ::String).returns(T.nilable(::CodeTeams::Team)) }
    def find(name); end

    sig { params(dir: ::String).returns(T::Array[::CodeTeams::Team]) }
    def for_directory(dir); end

    sig { params(string: ::String).returns(::String) }
    def tag_value_for(string); end

    sig { params(teams: T::Array[::CodeTeams::Team]).returns(T::Array[::String]) }
    def validation_errors(teams); end
  end
end

class CodeTeams::IncorrectPublicApiUsageError < ::StandardError; end

class CodeTeams::Plugin
  abstract!

  sig { params(team: ::CodeTeams::Team).void }
  def initialize(team); end

  class << self
    sig { returns(T::Array[T.class_of(CodeTeams::Plugin)]) }
    def all_plugins; end

    sig { params(team: ::CodeTeams::Team).returns(T.attached_class) }
    def for(team); end

    sig { params(base: T.untyped).void }
    def inherited(base); end

    sig { params(team: ::CodeTeams::Team, key: ::String).returns(::String) }
    def missing_key_error_message(team, key); end

    sig { params(teams: T::Array[::CodeTeams::Team]).returns(T::Array[::String]) }
    def validation_errors(teams); end

    private

    sig { params(team: ::CodeTeams::Team).returns(T.attached_class) }
    def register_team(team); end

    sig { returns(T::Hash[T.nilable(::String), T::Hash[::Class, ::CodeTeams::Plugin]]) }
    def registry; end
  end
end

module CodeTeams::Plugins; end

class CodeTeams::Plugins::Identity < ::CodeTeams::Plugin
  sig { returns(::CodeTeams::Plugins::Identity::IdentityStruct) }
  def identity; end

  class << self
    sig { override.params(teams: T::Array[::CodeTeams::Team]).returns(T::Array[::String]) }
    def validation_errors(teams); end
  end
end

class CodeTeams::Plugins::Identity::IdentityStruct < ::Struct
  def name; end
  def name=(_); end

  class << self
    def [](*_arg0); end
    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

class CodeTeams::Team
  sig { params(config_yml: T.nilable(::String), raw_hash: T::Hash[T.untyped, T.untyped]).void }
  def initialize(config_yml:, raw_hash:); end

  sig { params(other: ::Object).returns(T::Boolean) }
  def ==(other); end

  sig { returns(T.nilable(::String)) }
  def config_yml; end

  def eql?(*args, &blk); end

  sig { returns(::Integer) }
  def hash; end

  sig { returns(::String) }
  def name; end

  sig { returns(T::Hash[T.untyped, T.untyped]) }
  def raw_hash; end

  sig { returns(::String) }
  def to_tag; end

  class << self
    sig { params(raw_hash: T::Hash[T.untyped, T.untyped]).returns(::CodeTeams::Team) }
    def from_hash(raw_hash); end

    sig { params(config_yml: ::String).returns(::CodeTeams::Team) }
    def from_yml(config_yml); end
  end
end

CodeTeams::UNKNOWN_TEAM_STRING = T.let(T.unsafe(nil), String)
