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
        if files.count > 100
          # When looking at many files, expanding the cache out using Dir.glob and checking for intersections is faster
          files_by_mappers = files.map{ |f| [f, Set.new([]) ]}.to_h
          files_by_mappers.merge(files_by_mappers_via_expanded_cache)
        else
          # When looking at few files, using File.fnmatch is faster
          files_by_mappers_via_file_fnmatch(files)
        end
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
        @files_by_mappers ||= T.let(@files_by_mappers, T.nilable(FilesByMapper))
        @files_by_mappers ||= begin
          files_by_mappers = T.let({}, FilesByMapper)
          expanded_cache.each do |mapper_description, file_by_owner|
            file_by_owner.each do |file, owner|
              files_by_mappers[file] ||= Set.new([])
              files_by_mappers.fetch(file) << mapper_description
            end
          end

          files_by_mappers
        end
      end

      sig { params(files: T::Array[String]).returns(FilesByMapper) }
      def files_by_mappers_via_file_fnmatch(files)
        files_by_mappers = T.let({}, FilesByMapper)

        files.each do |file|
          files_by_mappers[file] ||= Set.new([])
          @raw_cache_contents.each do |mapper_description, globs_by_owner|
            # As much as I'd like to *not* special case the file annotations mapper, using File.fnmatch? on the thousands of files mapped by the
            # file annotations mapper is a lot of unnecessary extra work.
            # Therefore we can just check if the file is in the globs directly for file annotations, otherwise use File.fnmatch
            if mapper_description == OwnershipMappers::FileAnnotations::DESCRIPTION
              files_by_mappers.fetch(file) << mapper_description if globs_by_owner[file]
            else
              globs_by_owner.each do |glob, owner|
                if File.fnmatch?(glob, file, File::FNM_PATHNAME | File::FNM_EXTGLOB)
                  files_by_mappers.fetch(file) << mapper_description
                end
              end
            end
          end
        end

        files_by_mappers
      end
    end
  end
end
