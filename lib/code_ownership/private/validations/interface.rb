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

        class << self
          extend T::Sig

          sig { params(base: Class).void }
          def included(base)
            @validators ||= T.let(@validators, T.nilable(T::Array[Class]))
            @validators ||= []
            @validators << base
          end

          sig { returns(T::Array[Interface]) }
          def all
            T.unsafe(@validators).map(&:new)
          end
        end
      end
    end
  end
end
