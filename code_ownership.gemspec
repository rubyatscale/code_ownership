Gem::Specification.new do |spec|
  spec.name          = "code_ownership"
  spec.version       = '1.27.0'
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
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushes.'
  end
  # https://guides.rubygems.org/make-your-own-gem/#adding-an-executable
  # and
  # https://bundler.io/blog/2015/03/20/moving-bins-to-exe.html
  spec.executables = ['codeownership']

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir['README.md', 'sorbet/**/*', 'lib/**/*', 'bin/**/*']
  spec.require_paths = ['lib']

  spec.add_dependency 'bigrails-teams'
  spec.add_dependency 'parse_packwerk'
  spec.add_dependency 'sorbet-runtime'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'sorbet'
  spec.add_development_dependency 'tapioca'
end
