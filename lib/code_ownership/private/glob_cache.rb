# typed: strict
# frozen_string_literal: true

module CodeOwnership
  module Private
    class GlobCache
      extend T::Sig

      MapperDescription = T.type_alias { String }

      CacheShape = T.type_alias do
        T::Hash[
          MapperDescription,
          GlobsToOwningTeamMap
        ]
      end

      FilesByMapper = T.type_alias do
        T::Hash[
          String,
          T::Set[MapperDescription]
        ]
      end

      sig { params(raw_cache_contents: CacheShape).void }
      def initialize(raw_cache_contents)
        @raw_cache_contents = raw_cache_contents
      end

      sig { returns(CacheShape) }
      def raw_cache_contents
        @raw_cache_contents
      end

      sig { params(files: T::Array[String]).returns(FilesByMapper) }
      def mapper_descriptions_that_map_files(files)
        files_by_mappers = files.to_h { |f| [f, Set.new([])] }

        files_by_mappers_via_expanded_cache.each do |file, mappers|
          mappers.each do |mapper|
            T.must(files_by_mappers[file]) << mapper if files_by_mappers[file]
          end
        end

        files_by_mappers
      end

      private

      sig { returns(CacheShape) }
      def expanded_cache
        @expanded_cache = T.let(@expanded_cache, T.nilable(CacheShape))

        @expanded_cache ||= begin
          expanded_cache = {}
          @raw_cache_contents.each do |mapper_description, globs_by_owner|
            expanded_cache[mapper_description] = OwnerAssigner.assign_owners(globs_by_owner)
          end
          expanded_cache
        end
      end

      sig { returns(FilesByMapper) }
      def files_by_mappers_via_expanded_cache
        @files_by_mappers_via_expanded_cache ||= T.let(@files_by_mappers_via_expanded_cache, T.nilable(FilesByMapper))
        @files_by_mappers_via_expanded_cache ||= begin
          files_by_mappers = T.let({}, FilesByMapper)
          expanded_cache.each do |mapper_description, file_by_owner|
            file_by_owner.each_key do |file|
              files_by_mappers[file] ||= Set.new([])
              files_by_mappers.fetch(file) << mapper_description
            end
          end

          files_by_mappers
        end
      end
    end
  end
end
