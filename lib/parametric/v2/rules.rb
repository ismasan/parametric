# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Rules
      class Registry
        class UndefinedRuleError < KeyError
          def initialize(rule_name)
            @rule_name = rule_name
          end

          def message
            %(No rule registered with :#{@rule_name})
          end
        end

        RuleDef = Data.define(:name, :error_tpl, :callable, :metadata_key) do
          def error_for(result, value)
            return nil if callable.call(result, value)

            error_tpl % { value: value }
          end
        end

        def initialize
          @definitions = {}
        end

        def define(name, error_tpl, callable = nil, metadata_key: name, &block)
          name = name.to_sym
          callable ||= block
          @definitions[name] = RuleDef.new(name:, error_tpl:, callable:, metadata_key:)
        end

        def resolve(rules)
          rules.map { |(name, value)| [@definitions.fetch(name.to_sym) { raise UndefinedRuleError.new(name) }, value] }
        end
      end

      include Steppable

      def self.registry
        @registry ||= Registry.new
      end

      def self.define(...)
        registry.define(...)
      end

      attr_reader :metadata

      def initialize(rules)
        @rules = self.class.registry.resolve(rules)
        @metadata = @rules.each.with_object({}) { |(ruledef, value), m| m[ruledef.metadata_key] = value }
      end

      def inspect
        %(Rules[#{metadata.inspect}])
      end

      def ast
        [
          :rules,
          {},
          @rules.map { |(ruledef, value)| [ruledef.name, { ruledef.metadata_key => value }, []] }
        ]
      end

      private def _call(result)
        errors = @rules.map { |(ruledef, value)| ruledef.error_for(result, value) }.compact
        return result unless errors.any?

        result.halt(error: errors.join(', '))
      end
    end
  end
end
