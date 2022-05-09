# frozen_string_literal: true

# typed: strict

module CodeOwnership
  module Private
    module OwnershipMappers
      module Interface
        extend T::Sig
        extend T::Helpers

        interface!

        #
        # This should be fast when run with ONE file
        #
        sig do
          abstract.params(file: String).
            returns(T.nilable(::Teams::Team))
        end
        def map_file_to_owner(file)
        end

        #
        # This should be fast when run with MANY files
        #
        sig do
          abstract.params(files: T::Array[String]).
            returns(T::Hash[String, T.nilable(::Teams::Team)])
        end
        def map_files_to_owners(files)
        end

        sig do
          abstract.returns(T::Hash[String, T.nilable(::Teams::Team)])
        end
        def codeowners_lines_to_owners
        end

        sig { abstract.returns(String) }
        def description
        end

        sig { abstract.void }
        def bust_caches!
        end
      end
    end
  end
end
