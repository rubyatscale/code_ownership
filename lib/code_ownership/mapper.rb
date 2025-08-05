# frozen_string_literal: true

# typed: strict

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
    def map_file_to_owner(file)
    end

    #
    # This should be fast when run with MANY files
    #
    sig do
      abstract.params(files: T::Array[String])
        .returns(T::Hash[String, ::CodeTeams::Team])
    end
    def globs_to_owner(files)
    end

    #
    # This should be fast when run with MANY files
    #
    sig do
      abstract.params(cache: GlobsToOwningTeamMap, files: T::Array[String]).returns(GlobsToOwningTeamMap)
    end
    def update_cache(cache, files)
    end

    sig { abstract.returns(String) }
    def description
    end

    sig { abstract.void }
    def bust_caches!
    end

    sig { returns(Private::GlobCache) }
    def self.to_glob_cache
      glob_to_owner_map_by_mapper_description = {}

      Mapper.all.each do |mapper|
        mapped_files = mapper.globs_to_owner(Private.tracked_files)
        glob_to_owner_map_by_mapper_description[mapper.description] ||= {}

        mapped_files.each do |glob, owner|
          next if owner.nil?

          glob_to_owner_map_by_mapper_description.fetch(mapper.description)[glob] = owner
        end
      end

      Private::GlobCache.new(glob_to_owner_map_by_mapper_description)
    end
  end
end
