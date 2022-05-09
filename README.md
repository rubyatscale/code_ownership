# CodeOwnership
This gem helps engineering teams declare ownership of code.

Check out `lib/code_ownership.rb` to see the public API.

Check out `code_ownership_spec.rb` to see examples of how code ownership is used.

## Usage: Declaring Ownership
There are three ways to declare code ownership using this gem.
### Package-Based Ownership
Package based ownership integrates [`packwerk`](https://github.com/Shopify/packwerk) and has ownership defined per package. To define that all files within a package are owned by one team, configure your `package.yml` like this:
```yml
enforce_dependency: true
enforce_privacy: true
metadata:
  owner: Team
```

### Glob-Based Ownership
In your team's configured YML (see [`bigrails-teams`](https://github.com/bigrails/bigrails-teams)), you can set `owned_globs` to be a glob of files your team owns. For example, in `my_team.yml`:
```yml
name: My Team
owned_globs:
  - app/services/stuff_belonging_to_my_team/**/**
  - app/controllers/other_stuff_belonging_to_my_team/**/**
```
### File-Annotation Based Ownership
File annotations are a last resort if there is no clear home for your code. File annotations go at the top of your file, and look like this:
```ruby
# @team MyTeam
```
## Usage: Reading CodeOwnership
### `for_file`
`CodeOwnership.for_file`, given a relative path to a file returns a `Teams::Team` if there is a team that owns the file, `nil` otherwise.

```ruby
CodeOwnership.for_file('path/to/file/relative/to/application/root.rb')
```

Contributor note: If you are making updates to this method or the methods getting used here, please benchmark the performance of the new implementation against the current for both `for_files` and `for_file` (with 1, 100, 1000 files).

See `code_ownership_spec.rb` for examples.

### `for_backtrace`
`CodeOwnership.for_backtrace` can be given a backtrace and will either return `nil`, or a `Teams::Team`.

```ruby
CodeOwnership.for_backtrace(exception.backtrace)
```

This will go through the backtrace, and return the first found owner of the files associated with frames within the backtrace.

See `code_ownership_spec.rb` for an example.

### `for_class`

`CodeOwnership.for_class` can be given a class and will either return `nil`, or a `Teams::Team`.

```ruby
CodeOwnership.for_class(MyClass.name)
```

Under the hood, this finds the file where the class is defined and returns the owner of that file.

See `code_ownership_spec.rb` for an example.

## Usage: Generating a `CODEOWNERS` file

A `CODEOWNERS` file defines who owns specific files or paths in a repository. When you run `bin/codeownership validate`, a `.github/CODEOWNERS` file will automatically be generated and updated.

## Proper Configuration & Validation
CodeOwnership comes with a validation function to ensure the following things are true:
1) Only one mechanism is defining file ownership. That is -- you can't have a file annotation on a file owned via package-based or glob-based ownership. This helps make ownership behavior more clear by avoiding concerns about precedence.
2) All teams referenced as an owner for any file or package is a valid team (i.e. it's in the list of `Teams.all`).
3) All files have ownership. You can specify in `unowned_globs` to represent a TODO list of files to add ownership to.
3) The `.github/CODEOWNERS` file is up to date. This is automatically corrected and staged unless specified otherwise with `bin/codeownership validate --skip-autocorrect --skip-stage`. You can turn this validation off by setting `skip_codeowners_validation: true` in `code_ownership.yml`.

CodeOwnership also allows you to specify which globs and file extensions should be considered ownable.

Here is an example `config/code_ownership.yml`.
```yml
owned_globs:
  - '{app,components,config,frontend,lib,packs,spec}/**/*.{rb,rake,js,jsx,ts,tsx}'
unowned_globs:
  - db/**/*
  - app/services/some_file1.rb
  - app/services/some_file2.rb
  - frontend/javascripts/**/__generated__/**/*
```
You can call the validation function with the Ruby API 
```ruby
CodeOwnership.validate!
```
or the CLI
```
bin/codeownership validate
```

## Development

Please add to `CHANGELOG.md` and this `README.md` when you make make changes.
