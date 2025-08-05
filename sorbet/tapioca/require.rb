# typed: true
# frozen_string_literal: true

require 'bundler/setup'
require 'code_ownership/private/pack_ownership_validator'
require 'code_teams'
require 'debug'
require 'fileutils'
require 'json'
require 'optparse'
require 'packs-specification'
require 'packs/rspec/support'
require 'packwerk'
require 'pathname'
require 'sorbet-runtime'
require 'zeitwerk'
