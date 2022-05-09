# typed: strict

module CodeOwnership
  module Private
    module Validations
      module Interface
        extend T::Sig
        extend T::Helpers

        interface!

        sig { abstract.params(files: T::Array[String], autocorrect: T::Boolean, stage_changes: T::Boolean).returns(T::Array[String]) }
        def validation_errors(files:, autocorrect: true, stage_changes: true)
        end
      end
    end
  end
end
