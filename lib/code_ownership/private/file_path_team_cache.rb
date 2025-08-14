# frozen_string_literal: true

# typed: strict

module CodeOwnership
  module Private
    module FilePathTeamCache
      module_function

      extend T::Sig
      extend T::Helpers

      sig { params(file_path: String).returns(T.nilable(CodeTeams::Team)) }
      def get(file_path)
        cache[file_path]
      end

      sig { params(file_path: String, team: T.nilable(CodeTeams::Team)).void }
      def set(file_path, team)
        cache[file_path] = team
      end

      sig { params(file_path: String).returns(T::Boolean) }
      def cached?(file_path)
        cache.key?(file_path)
      end

      sig { void }
      def bust_cache!
        @cache = nil
      end

      sig { returns(T::Hash[String, T.nilable(CodeTeams::Team)]) }
      def cache
        @cache ||= T.let(@cache,
          T.nilable(T::Hash[String, T.nilable(CodeTeams::Team)]))
        @cache ||= {}
      end
    end
  end
end
