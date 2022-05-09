# typed: true

module CodeOwnership
  module Private
    module TeamPlugins
      class Ownership < Teams::Plugin
        extend T::Sig
        extend T::Helpers

        sig { returns(T::Array[String]) }
        def owned_globs
          @team.raw_hash['owned_globs'] || []
        end
      end
    end
  end
end
