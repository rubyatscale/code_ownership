# CodeOwnership

This gem helps engineering teams declare ownership of code. This gem works best in large, usually monolithic code bases where many teams work together.

Check out [`lib/code_ownership.rb`](https://github.com/rubyatscale/code_ownership/blob/main/lib/code_ownership.rb) to see the public API.

Check out [`code_ownership_spec.rb`](https://github.com/rubyatscale/code_ownership/blob/main/spec/lib/code_ownership_spec.rb) to see examples of how code ownership is used.

There is also a [companion VSCode Extension]([url](https://github.com/rubyatscale/code-ownership-vscode)) for this gem. Just search `Gusto.code-ownership-vscode` in the VSCode Extension Marketplace.

## Getting started

To get started there's a few things you should do.

1) Create a `config/code_ownership.yml` file and declare where your files live. Here's a sample to start with:
```yml
owned_globs:
  - '{app,components,config,frontend,lib,packs,spec}/**/*.{rb,rake,js,jsx,ts,tsx}'
js_package_paths: []
unowned_globs:
  - db/**/*
  - app/services/some_file1.rb
  - app/services/some_file2.rb
  - frontend/javascripts/**/__generated__/**/*
```
2) Declare some teams. Here's an example, that would live at `config/teams/operations.yml`:
```yml
name: Operations
github:
  team: '@my-org/operations-team'
```
3) Declare ownership. You can do this at a directory level or at a file level. All of the files within the `owned_globs` you declared in step 1 will need to have an owner assigned (or be opted out via `unowned_globs`). See the next section for more detail.
4) Run validations when you commit, and/or in CI. If you run validations in CI, ensure that if your `.github/CODEOWNERS` file gets changed, that gets pushed to the PR.

## Usage: Declaring Ownership

There are three ways to declare code ownership using this gem.

### Directory-Based Ownership
Directory based ownership allows for all files in that directory and all its sub-directories to be owned by one team. To define this, add a `.codeowner` file inside that directory with the name of the team as the contents of that file.
```
Team
```

### File-Annotation Based Ownership
File annotations are a last resort if there is no clear home for your code. File annotations go at the top of your file, and look like this:
```ruby
# @team MyTeam
```

### Package-Based Ownership
Package based ownership integrates [`packwerk`](https://github.com/Shopify/packwerk) and has ownership defined per package. To define that all files within a package are owned by one team, configure your `package.yml` like this:
```yml
enforce_dependency: true
enforce_privacy: true
metadata:
  owner: Team
```

You can also define `owner` as a top-level key, e.g.
```yml
enforce_dependency: true
enforce_privacy: true
owner: Team
```

To do this, add `code_ownership` to the `require` key of your `packwerk.yml`. See https://github.com/Shopify/packwerk/blob/main/USAGE.md#loading-extensions for more information.

### Glob-Based Ownership
In your team's configured YML (see [`code_teams`](https://github.com/rubyatscale/code_teams)), you can set `owned_globs` to be a glob of files your team owns. For example, in `my_team.yml`:
```yml
name: My Team
owned_globs:
  - app/services/stuff_belonging_to_my_team/**/**
  - app/controllers/other_stuff_belonging_to_my_team/**/**
```

### Javascript Package Ownership
Javascript package based ownership allows you to specify an ownership key in a `package.json`. To use this, configure your `package.json` like this:

```json
{
  // other keys
  "metadata": {
    "owner": "My Team"
  }
  // other keys
}
```

You can also tell `code_ownership` where to find JS packages in the configuration, like this:
```yml
js_package_paths:
  - frontend/javascripts/packages/*
  - frontend/other_location_for_packages/*
```

This defaults `**/`, which makes it look for `package.json` files across your application.

> [!NOTE]
> Javscript package ownership does not respect `unowned_globs`. If you wish to disable usage of this feature you can set `js_package_paths` to an empty list.
```yml
js_package_paths: []
```

### Custom Ownership
To enable custom ownership, you can inject your own custom classes into `code_ownership`.
To do this, first create a class that adheres to the `CodeOwnership::Mapper` and/or `CodeOwnership::Validator` interface.
Then, in `config/code_ownership.yml`, you can require that file:
```yml
require:
  - ./lib/my_extension.rb
```

Now, `bin/codeownership validate` will automatically include your new mapper and/or validator. See [`spec/lib/code_ownership/private/extension_loader_spec.rb](spec/lib/code_ownership/private/extension_loader_spec.rb) for an example of what this looks like.

## Usage: Reading CodeOwnership
### `for_file`
`CodeOwnership.for_file`, given a relative path to a file returns a `CodeTeams::Team` if there is a team that owns the file, `nil` otherwise.

```ruby
CodeOwnership.for_file('path/to/file/relative/to/application/root.rb')
```

Contributor note: If you are making updates to this method or the methods getting used here, please benchmark the performance of the new implementation against the current for both `for_files` and `for_file` (with 1, 100, 1000 files).

See `code_ownership_spec.rb` for examples.

### `for_backtrace`
`CodeOwnership.for_backtrace` can be given a backtrace and will either return `nil`, or a `CodeTeams::Team`.

```ruby
CodeOwnership.for_backtrace(exception.backtrace)
```

This will go through the backtrace, and return the first found owner of the files associated with frames within the backtrace.

See `code_ownership_spec.rb` for an example.

### `for_class`

`CodeOwnership.for_class` can be given a class and will either return `nil`, or a `CodeTeams::Team`.

```ruby
CodeOwnership.for_class(MyClass)
```

Under the hood, this finds the file where the class is defined and returns the owner of that file.

See `code_ownership_spec.rb` for an example.

### `for_team`
`CodeOwnership.for_team` can be used to generate an ownership report for a team.
```ruby
CodeOwnership.for_team('My Team')
```

You can shovel this into a markdown file for easy viewing using the CLI:
```
bin/codeownership for_team 'My Team' > tmp/ownership_report.md
```

## Usage: Generating a `CODEOWNERS` file

A `CODEOWNERS` file defines who owns specific files or paths in a repository. When you run `bin/codeownership validate`, a `.github/CODEOWNERS` file will automatically be generated and updated.

## Proper Configuration & Validation

CodeOwnership comes with a validation function to ensure the following things are true:

1) Only one mechanism is defining file ownership. That is -- you can't have a file annotation on a file owned via package-based or glob-based ownership. This helps make ownership behavior more clear by avoiding concerns about precedence.
2) All teams referenced as an owner for any file or package is a valid team (i.e. it's in the list of `CodeTeams.all`).
3) All files have ownership. You can specify in `unowned_globs` to represent a TODO list of files to add ownership to.
3) The `.github/CODEOWNERS` file is up to date. This is automatically corrected and staged unless specified otherwise with `bin/codeownership validate --skip-autocorrect --skip-stage`. You can turn this validation off by setting `skip_codeowners_validation: true` in `config/code_ownership.yml`.

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
