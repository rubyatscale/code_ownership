# frozen_string_literal: true
# typed: strict

module CodeOwnership
  module Private
    module FilePathTeamCache
      extend T::Sig

      sig { params(file_path: String).returns(T.nilable(CodeTeams::Team)) }
      def self.get(file_path)
        cache[file_path]
      end

      sig { params(file_path: String, team: T.nilable(CodeTeams::Team)).void }
      def self.set(file_path, team)
        cache[file_path] = team
      end

      sig { params(file_path: String).returns(T::Boolean) }
      def self.cached?(file_path)
        cache.key?(file_path)
      end

      sig { void }
      def self.bust_cache!
        @cache = nil
      end

      sig { returns(T::Hash[String, T.nilable(CodeTeams::Team)]) }
      def self.cache
        @cache ||= T.let(@cache,
          T.nilable(T::Hash[String, T.nilable(CodeTeams::Team)]))
        @cache ||= {}
      end
    end
  end
end
