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
        mappers = @mappers || []

        # Sort mappers by priority with file annotations last
        sorted_mappers = mappers.sort_by do |mapper_class|
          [priority_for_mapper_class(mapper_class)]
        end

        sorted_mappers.map(&:new)
      end

      private

      sig { params(mapper_class: T::Class[Mapper]).returns(T.nilable(Integer)) }
      def priority_for_mapper_class(mapper_class)
        priority_hash[mapper_class]
      end

      sig { returns(T::Hash[T::Class[Mapper], Integer]) }
      def priority_hash
        {
          Private::OwnershipMappers::FileAnnotations => 6,
          Private::OwnershipMappers::DirectoryOwnership => 2,
          Private::OwnershipMappers::PackageOwnership => 3,
          Private::OwnershipMappers::JsPackageOwnership => 4,
          Private::OwnershipMappers::TeamGlobs => 1,
          Private::OwnershipMappers::TeamYmlOwnership => 5
        }
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

    sig { abstract.void }
    def bust_caches!; end

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
