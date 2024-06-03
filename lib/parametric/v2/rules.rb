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

        RuleDef = Data.define(:name, :error_tpl, :callable, :metadata_key)

        Rule = Data.define(:rule_def, :arg_value, :error_str) do
          def self.build(rule_def, arg_value)
            error_str = rule_def.error_tpl % { value: arg_value }
            new(rule_def, arg_value, error_str)
          end

          def name = rule_def.name
          def metadata_key = rule_def.metadata_key

          def error_for(result)
            return nil if rule_def.callable.call(result, arg_value)

            error_str
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

        # Ex. size: 3, match: /foo/
        def resolve(rule_specs)
          rule_specs.map do |(name, arg_value)|
            rule_def = @definitions.fetch(name.to_sym) { raise UndefinedRuleError.new(name) }
            Rule.build(rule_def, arg_value)
          end
        end
      end

      include Steppable

      def self.registry
        @registry ||= Registry.new
      end

      def self.define(...)
        registry.define(...)
      end

      # Ex. new(size: 3, match: /foo/)
      def initialize(rule_specs)
        @rules = self.class.registry.resolve(rule_specs)
      end

      def ast
        [
          :rules,
          BLANK_HASH,
          @rules.map { |rule| [rule.name, { rule.metadata_key => rule.arg_value }, []] }
        ]
      end

      def call(result)
        errors = []
        err = nil
        @rules.each do |rule|
          err = rule.error_for(result)
          errors << err if err
        end
        return result unless errors.any?

        result.halt(error: errors.join(', '))
      end
    end
  end
end
