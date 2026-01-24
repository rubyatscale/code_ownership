require 'rb_sys/extensiontask'

RbSys::ExtensionTask.new('code_ownership', GEMSPEC) do |ext|
  ruby_minor = RUBY_VERSION[/\d+\.\d+/]
  ext.lib_dir = "lib/code_ownership/#{ruby_minor}"
end
