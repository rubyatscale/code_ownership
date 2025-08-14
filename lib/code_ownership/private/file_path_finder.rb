# frozen_string_literal: true

# typed: strict

module CodeOwnership
  module Private
    module FilePathFinder
      module_function

      extend T::Sig
      extend T::Helpers

      # Returns a string version of the relative path to a Rails constant,
      # or nil if it can't find anything
      sig { params(klass: T.nilable(T.any(T::Class[T.anything], Module))).returns(T.nilable(String)) }
      def path_from_klass(klass)
        if klass
          path = Object.const_source_location(klass.to_s)&.first
          (path && Pathname.new(path).relative_path_from(Pathname.pwd).to_s) || nil
        end
      rescue NameError
        nil
      end

      sig { params(backtrace: T.nilable(T::Array[String])).returns(T::Enumerable[String]) }
      def from_backtrace(backtrace)
        return [] unless backtrace

        # The pattern for a backtrace hasn't changed in forever and is considered
        # stable: https://github.com/ruby/ruby/blob/trunk/vm_backtrace.c#L303-L317
        #
        # This pattern matches a line like the following:
        #
        #   ./app/controllers/some_controller.rb:43:in `block (3 levels) in create'
        #
        backtrace_line = if RUBY_VERSION >= '3.4.0'
                           %r{\A(#{Pathname.pwd}/|\./)?
                               (?<file>.+)       # Matches 'app/controllers/some_controller.rb'
                               :
                               (?<line>\d+)      # Matches '43'
                               :in\s
                               '(?<function>.*)' # Matches "`block (3 levels) in create'"
                             \z}x
                         else
                           %r{\A(#{Pathname.pwd}/|\./)?
                               (?<file>.+)       # Matches 'app/controllers/some_controller.rb'
                               :
                               (?<line>\d+)      # Matches '43'
                               :in\s
                               `(?<function>.*)' # Matches "`block (3 levels) in create'"
                             \z}x
                         end

        backtrace.lazy.filter_map do |line|
          match = line.match(backtrace_line)
          next unless match

          T.must(match[:file])
        end
      end
    end
  end
end
