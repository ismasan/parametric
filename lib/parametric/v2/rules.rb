# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Rules
      UnsupportedRuleError = Class.new(StandardError)
      UndefinedRuleError = Class.new(KeyError)

      class Registry
        RuleDef = Data.define(:name, :error_tpl, :callable, :metadata_key, :expects) do
          def supports?(type)
            case expects
            when Symbol
              type.public_instance_methods.include?(expects)
            when Array then expects.include?(type)
            when Class then type <= expects
            when Object then true
            else raise "Unexpected expects: #{expects}"
            end
          end
        end

        Rule = Data.define(:rule_def, :arg_value, :error_str) do
          def self.build(rule_def, arg_value)
            error_str = format(rule_def.error_tpl, value: arg_value)
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
          @definitions = Hash.new { |h, k| h[k] = Set.new }
        end

        def define(name, error_tpl, callable = nil, metadata_key: name, expects: Object, &block)
          name = name.to_sym
          callable ||= block
          @definitions[name] << RuleDef.new(name:, error_tpl:, callable:, metadata_key:, expects:)
        end

        # Ex. size: 3, match: /foo/
        def resolve(rule_specs, for_type)
          rule_specs.map do |(name, arg_value)|
            rule_defs = @definitions.fetch(name.to_sym) { raise UndefinedRuleError, "no rule defined with :#{name}" }
            rule_def = rule_defs.find { |rd| rd.supports?(for_type) }
            raise UnsupportedRuleError, "No :#{name} rule defined for type #{for_type}" unless rule_def

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
      def initialize(rule_specs, for_type)
        @rules = self.class.registry.resolve(rule_specs, for_type).freeze
        freeze
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

        result.halt(errors: errors.join(', '))
      end
    end
  end
end
