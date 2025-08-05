# typed: strict
# frozen_string_literal: true

require 'packwerk'

module CodeOwnership
  module Private
    class PackOwnershipValidator
      extend T::Sig
      include Packwerk::Validator

      sig { override.params(package_set: Packwerk::PackageSet, configuration: Packwerk::Configuration).returns(Result) }
      def call(package_set, configuration)
        Result.new(ok: true)
      end

      sig { override.returns(T::Array[String]) }
      def permitted_keys
        %w[owner]
      end
    end
  end
end
