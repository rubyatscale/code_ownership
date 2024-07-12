# typed: strict
# frozen_string_literal: true

module CodeOwnership
  module Private
    # This class handles loading extensions to code_ownership using the `require` directive
    # in the `code_ownership.yml` configuration.
    module ExtensionLoader
      class << self
        extend T::Sig
        sig { params(require_directive: String).void }
        def load(require_directive)
          # We want to transform the require directive to behave differently
          # if it's a specific local file being required versus a gem
          if require_directive.start_with?('.')
            require File.join(Pathname.pwd, require_directive)
          else
            require require_directive
          end
        end
      end
    end
  end
end
