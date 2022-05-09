# frozen_string_literal: true

# typed: true

module CodeOwnership
  module Private
    # Modeled off of ParsePackwerk
    module ParseJsPackages
      extend T::Sig

      ROOT_PACKAGE_NAME = 'root'
      PACKAGE_JSON_NAME = T.let('package.json', String)
      METADATA = 'metadata'

      class Package < T::Struct
        extend T::Sig

        const :name, String
        const :metadata, T::Hash[String, T.untyped]

        sig { params(pathname: Pathname).returns(Package) }
        def self.from(pathname)
          package_loaded_json = JSON.parse(pathname.read)

          package_name = if pathname.dirname == Pathname.new('.')
            ROOT_PACKAGE_NAME
          else
            pathname.dirname.cleanpath.to_s
          end

          new(
            name: package_name,
            metadata: package_loaded_json[METADATA] || {}
          )
        end

        sig { returns(Pathname) }
        def directory
          root_pathname = Pathname.new('.')
          name == ROOT_PACKAGE_NAME ? root_pathname.cleanpath : root_pathname.join(name).cleanpath
        end
      end

      sig do
        returns(T::Array[Package])
      end
      def self.all
        package_glob_patterns = Private.configuration.js_package_paths.map do |pathspec|
          File.join(pathspec, PACKAGE_JSON_NAME)
        end

        # The T.unsafe is because the upstream RBI is wrong for Pathname.glob
        T.unsafe(Pathname).glob(package_glob_patterns).map(&:cleanpath).map do |path|
          Package.from(path)
        end
      end
    end
  end
end
