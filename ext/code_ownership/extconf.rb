# frozen_string_literal: true

require 'mkmf'
require 'rb_sys/mkmf'

ruby_minor = RUBY_VERSION[/\d+\.\d+/]
create_rust_makefile("code_ownership/#{ruby_minor}/code_ownership") do |ext|
  ext.extra_cargo_args += ['--crate-type', 'cdylib']
  ext.extra_cargo_args += ['--package', 'code_ownership']
end
