# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rb_sys/extensiontask"

task build: :compile    

GEMSPEC = Gem::Specification.load("code_ownership.gemspec")

RbSys::ExtensionTask.new("libcodeowners", GEMSPEC) do |ext|
  ext.lib_dir = "lib/libcodeowners"
end

task default: %i[compile spec]
