require_relative 'lib/code_ownership/version'

Gem::Specification.new do |spec|
  spec.name          = 'code_ownership'
  spec.version       = CodeOwnership::VERSION
  spec.authors       = ['Gusto Engineers']
  spec.email         = ['dev@gusto.com']
  spec.summary       = 'A gem to help engineering teams declare ownership of code'
  spec.description   = 'A gem to help engineering teams declare ownership of code'
  spec.homepage      = 'https://github.com/rubyatscale/code_ownership'
  spec.license       = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/rubyatscale/code_ownership'
    spec.metadata['changelog_uri'] = 'https://github.com/rubyatscale/code_ownership/releases'
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
    spec.metadata['cargo_crate_name'] = 'code_ownership'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushes.'
  end

  spec.required_ruby_version = '>= 3.2'

  # https://guides.rubygems.org/make-your-own-gem/#adding-an-executable
  # and
  # https://bundler.io/blog/2015/03/20/moving-bins-to-exe.html
  spec.executables = ['codeownership']

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir['{lib,ext}/**/*', 'LICENSE', 'README.md', 'Cargo.*']
  spec.files.reject! { |f| File.directory?(f) }
  spec.files.reject! { |f| f =~ /\.(dll|so|dylib|lib|bundle)\Z/ }
  spec.require_paths = ['lib']
  spec.extensions = ['ext/code_ownership/Cargo.toml']

  spec.add_dependency 'code_teams', '~> 1.0'
  spec.add_dependency 'packs-specification'
  spec.add_dependency 'sorbet-runtime', '>= 0.5.11249'

  spec.add_development_dependency 'debug'
  spec.add_development_dependency 'packwerk'
  spec.add_development_dependency 'railties'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rb_sys', '~> 0.9.63'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'sorbet'
  spec.add_development_dependency 'tapioca'
end
