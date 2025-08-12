# frozen_string_literal: true

# typed: strict

# deprecated
# This file only exists to temporarily support the old mapper interface, but it doesn't do anything
module CodeOwnership
  module Mapper
    extend T::Sig
    extend T::Helpers

    interface!

    class << self
      extend T::Sig

      sig { params(base: T::Class[Mapper]).void }
      def included(base)
        @mappers ||= T.let(@mappers, T.nilable(T::Array[T::Class[Mapper]]))
        @mappers ||= []
        @mappers << base
      end

      sig { returns(T::Array[Mapper]) }
      def all
        (@mappers || []).map(&:new)
      end
    end

    #
    # This should be fast when run with ONE file
    #
    sig do
      abstract.params(file: String)
        .returns(T.nilable(::CodeTeams::Team))
    end
    def map_file_to_owner(file); end

    #
    # This should be fast when run with MANY files
    #
    sig do
      abstract.params(files: T::Array[String])
        .returns(T::Hash[String, ::CodeTeams::Team])
    end
    def globs_to_owner(files); end

    #
    # This should be fast when run with MANY files
    #
    sig do
      abstract.params(cache: GlobsToOwningTeamMap, files: T::Array[String]).returns(GlobsToOwningTeamMap)
    end
    def update_cache(cache, files); end

    sig { abstract.returns(String) }
    def description; end
  end
end
