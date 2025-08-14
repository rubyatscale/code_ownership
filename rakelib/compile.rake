require 'rb_sys/extensiontask'

RbSys::ExtensionTask.new('code_ownership', GEMSPEC) do |ext|
  ext.lib_dir = 'lib/code_ownership'
end
