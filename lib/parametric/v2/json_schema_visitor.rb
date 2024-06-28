# frozen_string_literal: true

require 'parametric/v2/visitor_handlers'

module Parametric
  module V2
    class JSONSchemaVisitor
      include VisitorHandlers

      def self.call(type)
        { 
          '$schema' => 'https://json-schema.org/draft-08/schema#',
        }.merge(new.visit(type))
      end

      on(:any) do |type, props|
        props
      end

      on(:pipeline) do |type, props|
        visit(type.type, props)
      end

      on(:step) do |type, props|
        props.merge(type._metadata)
      end

      on(:hash) do |type, props|
        props.merge(
          type: 'object',
          properties: type._schema.each_with_object({}) do |(key, value), hash|
            hash[key.to_s] = visit(value)
          end,
          required: type._schema.select { |key, value| !key.optional? }.keys.map(&:to_s)
        )
      end

      on(:and) do |type, props|
        left = visit(type.left)
        right = visit(type.right)
        type = right[:type] || left[:type]
        props = props.merge(left).merge(right)
        props = props.merge(type:) if type
        props
      end

      # A "default" value is usually an "or" of expected_value | (undefined >> static_value)
      on(:or) do |type, props|
        left = visit(type.left)
        right = visit(type.right)
        any_of = [left, right].uniq
        if any_of.size == 1
          props.merge(left)
        elsif any_of.size == 2 && (defidx = any_of.index { |p| p.key?(:default) })
          val = any_of[defidx == 0 ? 1 : 0]
          props.merge(val).merge(default: any_of[defidx][:default])
        else
          props.merge(anyOf: any_of)
        end
      end

      on(:value) do |type, props|
        props = case type.value
        when ::String, ::Symbol, ::Numeric
          props.merge(const: type.value)
        else
          props
        end

        visit(type.value, props)
      end

      on(:transform) do |type, props|
        visit(type.target_type, props)
      end

      on(:undefined) do |type, props|
        props
      end

      on(:static) do |type, props|
        props = case type.value
        when ::String, ::Symbol, ::Numeric
          props.merge(const: type.value, default: type.value)
        else
          props
        end

        visit(type.value, props)
      end

      on(:rules) do |type, props|
        type.rules.reduce(props) do |acc, rule|
          acc.merge(visit(rule))
        end
      end

      on(:rule_included_in) do |type, props|
        props.merge(enum: type.arg_value)
      end

      on(:match) do |type, props|
        visit(type.matcher, props)
      end

      on(:boolean) do |type, props|
        props.merge(type: 'boolean')
      end

      on(::String) do |type, props|
        props.merge(type: 'string')
      end

      on(::Integer) do |type, props|
        props.merge(type: 'integer')
      end

      on(::Numeric) do |type, props|
        props.merge(type: 'number')
      end

      on(::BigDecimal) do |type, props|
        props.merge(type: 'number')
      end

      on(::Float) do |type, props|
        props.merge(type: 'number')
      end

      on(::TrueClass) do |type, props|
        props.merge(type: 'boolean')
      end

      on(::NilClass) do |type, props|
        props.merge(type: 'null')
      end

      on(::FalseClass) do |type, props|
        props.merge(type: 'boolean')
      end

      on(::Regexp) do |type, props|
        props.merge(pattern: type.source)
      end

      on(::Range) do |type, props|
        opts = {}
        opts[:minimum] = type.min if type.begin
        opts[:maximum] = type.max if type.end
        props.merge(opts)
      end

      on(:metadata) do |type, props|
        # TODO: here we should filter out the metadata that is not relevant for JSON Schema
        props.merge(type.metadata)
      end

      on(:hash_map) do |type, props|
        {
          type: 'object',
          patternProperties: {
            '.*' => visit(type.value_type)
          }
        }
      end

      on(:constructor) do |type, props|
        visit(type.type, props)
      end

      on(:array) do |type, props|
        items = visit(type.element_type)
        { type: 'array', items: }
      end

      on(:tuple) do |type, props|
        items = type.types.map { |t| visit(t) }
        { type: 'array', prefixItems: items }
      end

      on(:tagged_hash) do |type, props|
        required = Set.new
        result = {
          type: 'object',
          properties: {}
        }

        key = type.key.to_s
        children  = type.types.map { |c| visit(c) }
        key_enum =  children.map { |c| c[:properties][key][:const] }
        key_type =  children.map { |c| c[:properties][key][:type] }
        required << key
        result[:properties][key] = { type: key_type.first, enum: key_enum }
        result[:allOf] = children.map do |child|
          child_prop = child[:properties][key]

          {
            if: {
              properties: { key => child_prop.slice(:const, :type) }
            },
            then: child.except(:type)
          }
        end

        result.merge(required: required.to_a)
      end
    end
  end
end
