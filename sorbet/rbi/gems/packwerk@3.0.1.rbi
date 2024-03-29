# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `packwerk` gem.
# Please instead update this file by running `bin/tapioca gem packwerk`.


# @abstract Subclasses must implement the `abstract` methods below.
#
# source://packwerk//lib/packwerk/validator.rb#9
module Packwerk::Validator

  abstract!

  # @abstract
  #
  # source://packwerk//lib/packwerk/validator.rb#36
  sig do
    abstract
      .params(
        package_set: Packwerk::PackageSet,
        configuration: ::Packwerk::Configuration
      ).returns(::Packwerk::Validator::Result)
  end
  def call(package_set, configuration); end

  # source://packwerk//lib/packwerk/validator.rb#67
  sig do
    params(
      results: T::Array[::Packwerk::Validator::Result],
      separator: ::String,
      before_errors: ::String,
      after_errors: ::String
    ).returns(::Packwerk::Validator::Result)
  end
  def merge_results(results, separator: T.unsafe(nil), before_errors: T.unsafe(nil), after_errors: T.unsafe(nil)); end

  # source://packwerk//lib/packwerk/validator.rb#55
  sig { params(configuration: ::Packwerk::Configuration).returns(T.any(::String, T::Array[::String])) }
  def package_glob(configuration); end

  # source://packwerk//lib/packwerk/validator.rb#48
  sig do
    params(
      configuration: ::Packwerk::Configuration,
      glob_pattern: T.nilable(T.any(::String, T::Array[::String]))
    ).returns(T::Array[::String])
  end
  def package_manifests(configuration, glob_pattern = T.unsafe(nil)); end

  # source://packwerk//lib/packwerk/validator.rb#40
  sig { params(configuration: ::Packwerk::Configuration, setting: T.untyped).returns(T.untyped) }
  def package_manifests_settings_for(configuration, setting); end

  # @abstract
  #
  # source://packwerk//lib/packwerk/validator.rb#32
  sig { abstract.returns(T::Array[::String]) }
  def permitted_keys; end

  # source://packwerk//lib/packwerk/validator.rb#86
  sig { params(configuration: ::Packwerk::Configuration, path: ::String).returns(::Pathname) }
  def relative_path(configuration, path); end

  class << self
    # source://packwerk//lib/packwerk/validator.rb#26
    sig { returns(T::Array[::Packwerk::Validator]) }
    def all; end

    # source://packwerk//lib/packwerk/validator.rb#19
    sig { params(base: ::Class).void }
    def included(base); end
  end
end

# source://packwerk//lib/packwerk/validator/result.rb#6
class Packwerk::Validator::Result < ::T::Struct
  const :ok, T::Boolean
  const :error_value, T.nilable(::String)

  # source://packwerk//lib/packwerk/validator/result.rb#13
  sig { returns(T::Boolean) }
  def ok?; end

  class << self
    # source://sorbet-runtime/0.5.10821/lib/types/struct.rb#13
    def inherited(s); end
  end
end

class Packwerk::PackageSet; end
class Packwerk::Configuration; end
