# typed: strict
# frozen_string_literal: true

module CodeOwnership
  module Private
    class GlobCache
      extend T::Sig

      MapperDescription = T.type_alias { String }
      GlobsByMapper = T.type_alias { T::Hash[String, CodeTeams::Team] }

      CacheShape = T.type_alias do
        T::Hash[
          MapperDescription,
          GlobsByMapper
        ]
      end

      FilesByMapper = T.type_alias do
        T::Hash[
          String,
          T::Array[MapperDescription]
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

      sig { returns(CacheShape) }
      def expanded_cache
        @expanded_cache = T.let(@expanded_cache, T.nilable(CacheShape))

        @expanded_cache ||= begin
          expanded_cache = {}
          @raw_cache_contents.each do |mapper_description, globs_by_owner|
            expanded_cache[mapper_description] = {}
            globs_by_owner.each do |glob, owner|
              Dir.glob(glob).each do |file, owner|
                expanded_cache[mapper_description][file] = owner
              end
            end
          end
          
          expanded_cache
        end
      end

      sig { returns(FilesByMapper) }
      def files_by_mapper
        @files_by_mapper ||= T.let(@files_by_mapper, T.nilable(FilesByMapper))
        @files_by_mapper ||= begin
          files_by_mapper = {}
          expanded_cache.each do |mapper_description, file_by_owner|
            file_by_owner.each do |file, owner|
              files_by_mapper[file] ||= []
              files_by_mapper[file] << mapper_description
            end
          end

          files_by_mapper
        end
      end
    end
  end
end
