# typed: strict

module CodeOwnership
  class Configuration < T::Struct
    extend T::Sig
    DEFAULT_JS_PACKAGE_PATHS = T.let(['**/'], T::Array[String])

    const :owned_globs, T::Array[String]
    const :unowned_globs, T::Array[String]
    const :js_package_paths, T::Array[String]
    const :unbuilt_gems_path, T.nilable(String)
    const :skip_codeowners_validation, T::Boolean
    const :raw_hash, T::Hash[T.untyped, T.untyped]
    const :require_github_teams, T::Boolean
    prop :use_git_ls_files, T::Boolean

    sig { returns(Configuration) }
    def self.fetch
      config_hash = YAML.load_file('config/code_ownership.yml')

      if config_hash.key?("require")
        config_hash["require"].each do |require_directive|
          Private::ExtensionLoader.load(require_directive)
        end
      end

      new(
        owned_globs: config_hash.fetch('owned_globs', []),
        unowned_globs: config_hash.fetch('unowned_globs', []),
        js_package_paths: js_package_paths(config_hash),
        skip_codeowners_validation: config_hash.fetch('skip_codeowners_validation', false),
        raw_hash: config_hash,
        require_github_teams: config_hash.fetch('require_github_teams', false),
        use_git_ls_files: config_hash.fetch('use_git_ls_files', false)
      )
    end

    sig { params(config_hash: T::Hash[T.untyped, T.untyped]).returns(T::Array[String]) }
    def self.js_package_paths(config_hash)
      specified_package_paths = config_hash['js_package_paths']
      if specified_package_paths.nil?
        DEFAULT_JS_PACKAGE_PATHS.dup
      else
        Array(specified_package_paths)
      end
    end
  end
end
