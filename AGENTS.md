This file provides guidance to AI coding agents when working with code in this repository.

## What this project is

`code_ownership` is a Ruby gem that helps engineering teams declare and query ownership of code. It supports multiple ownership mechanisms: package-based ownership (via `package.yml`), team-based glob patterns, and file annotations.

## Commands

```bash
bundle install

# Run all tests (RSpec) — note: includes a native extension compile step
bundle exec rake default   # compiles extension + runs specs

# Run specs directly (after compiling)
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/path/to/spec.rb

# Lint
bundle exec rubocop
bundle exec rubocop -a  # auto-correct

# Type checking (Sorbet)
bundle exec srb tc
```

## Architecture

- `lib/code_ownership.rb` — public API: `CodeOwnership.for_file`, `CodeOwnership.validate!`, `CodeOwnership.for_team`
- `lib/code_ownership/` — mapper plugins (each ownership mechanism is a mapper), `Ownership` value object, configuration loading, and CLI
- `spec/` — RSpec tests
