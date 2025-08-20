# frozen_string_literal: true

# typed: strict

module CodeOwnership
  module Private
    class ForFileOutputBuilder
      extend T::Sig
      private_class_method :new

      sig { params(file_path: String, json: T::Boolean, verbose: T::Boolean).void }
      def initialize(file_path:, json:, verbose:)
        @file_path = file_path
        @json = json
        @verbose = verbose
      end

      sig { params(file_path: String, json: T::Boolean, verbose: T::Boolean).returns(String) }
      def self.build(file_path:, json:, verbose:)
        new(file_path: file_path, json: json, verbose: verbose).build
      end

      UNOWNED_OUTPUT = T.let(
        {
          team_name: 'Unowned',
          team_yml: 'Unowned'
        },
        T::Hash[Symbol, T.untyped]
      )

      sig { returns(String) }
      def build
        result_hash = @verbose ? build_verbose : build_terse

        return result_hash.to_json if @json

        build_message_for(result_hash)
      end

      private

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def build_verbose
        result = CodeOwnership.for_file_verbose(@file_path)
        return UNOWNED_OUTPUT if result.nil?

        {
          team_name: result[:team_name],
          team_yml: result[:team_config_yml],
          reasons: result[:reasons]
        }
      end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def build_terse
        team = CodeOwnership.for_file(@file_path)

        if team.nil?
          UNOWNED_OUTPUT
        else
          {
            team_name: team.name,
            team_yml: team.config_yml
          }
        end
      end

      sig { params(result_hash: T::Hash[Symbol, T.untyped]).returns(String) }
      def build_message_for(result_hash)
        messages = ["Team: #{result_hash[:team_name]}", "Team YML: #{result_hash[:team_yml]}"]
        reasons_list = T.let(Array(result_hash[:reasons]), T::Array[String])
        messages << build_reasons_message(reasons_list) unless reasons_list.empty?
        messages.last << "\n"
        messages.join("\n")
      end

      sig { params(reasons: T::Array[String]).returns(String) }
      def build_reasons_message(reasons)
        "Reasons:\n- #{reasons.join("\n-")}"
      end
    end
  end
end
