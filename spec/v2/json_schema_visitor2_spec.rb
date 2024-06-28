# frozen_string_literal: true

require 'spec_helper'
require 'parametric/v2'
require 'parametric/v2/json_schema_visitor'

module Parametric
  module V2
    class HashVisitor
      def initialize(preamble = BLANK_HASH)
        @preamble = preamble
        @handlers = {}
      end

      def on(node_name, handler = nil, &block)
        @handlers[node_name] = handler || block
        self
      end

      def call(type)
        @preamble.merge(visit(type))
      end

      def visit(type, props = BLANK_HASH)
        key = type.respond_to?(:node_name) ? type.node_name : (type.is_a?(::Class) ? type : type.class)
        visit_with(key, type, props)
      end

      def visit_with(key, type, props)
        handler = @handlers[key]
        raise "No handler for #{key}" unless handler
        props.merge(handler.call(self, type, props))
      end
    end

    JSONSchemaVisitor2 = HashVisitor.new({ '$schema' => 'http://json-schema.org/draft-08/schema#' }).tap do |v|
      v.on(:hash) do |visitor, type, props|
        props.merge(
          type: 'object',
          properties: type._schema.each_with_object({}) do |(key, value), hash|
            hash[key.to_s] = visitor.visit(value)
          end,
          required: type._schema.select { |key, value| !key.optional? }.keys.map(&:to_s)
        )
      end

      v.on(:and) do |visitor, type, props|
        left = visitor.visit(type.left)
        right = visitor.visit(type.right)
        type = right[:type] || left[:type]
        props = props.merge(left).merge(right)
        props = props.merge(type:) if type
        props
      end

      # A "default" value is usually an "or" of expected_value | (undefined >> static_value)
      v.on(:or) do |visitor, type, props|
        left = visitor.visit(type.left)
        right = visitor.visit(type.right)
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

      v.on(:value) do |visitor, type, props|
        props = case type.value
        when ::String, ::Symbol, ::Numeric
          props.merge(const: type.value)
        else
          props
        end

        visitor.visit(type.value, props)
      end

      v.on(:undefined) do |visitor, type, props|
        props
      end

      v.on(:static) do |visitor, type, props|
        props = case type.value
        when ::String, ::Symbol, ::Numeric
          props.merge(const: type.value, default: type.value)
        else
          props
        end

        visitor.visit(type.value, props)
      end

      v.on(:rules) do |visitor, type, props|
        type.rules.reduce(props) do |acc, rule|
          acc.merge(visitor.visit(rule))
        end
      end

      v.on(:match) do |visitor, type, props|
        visitor.visit(type.matcher, props)
      end

      v.on(:boolean) do |visitor, type, props|
        props.merge(type: 'boolean')
      end

      v.on(::String) do |visitor, type, props|
        props.merge(type: 'string')
      end

      v.on(::Integer) do |visitor, type, props|
        props.merge(type: 'integer')
      end

      v.on(::Numeric) do |visitor, type, props|
        props.merge(type: 'number')
      end

      v.on(::BigDecimal) do |visitor, type, props|
        props.merge(type: 'number')
      end

      v.on(::Float) do |visitor, type, props|
        props.merge(type: 'number')
      end

      v.on(::TrueClass) do |visitor, type, props|
        props.merge(type: 'boolean')
      end

      v.on(::NilClass) do |visitor, type, props|
        props.merge(type: 'null')
      end

      v.on(::FalseClass) do |visitor, type, props|
        props.merge(type: 'boolean')
      end

      v.on(::Regexp) do |visitor, type, props|
        props.merge(pattern: type.source)
      end

      v.on(::Range) do |visitor, type, props|
        opts = {}
        opts[:minimum] = type.min if type.begin
        opts[:maximum] = type.max if type.end
        props.merge(opts)
      end

      v.on(:metadata) do |visitor, type, props|
        # TODO: here we should filter out the metadata that is not relevant for JSON Schema
        props.merge(type.metadata)
      end

      v.on(:hash_map) do |visitor, type, props|
        {
          type: 'object',
          patternProperties: {
            '.*' => visitor.visit(type.value_type)
          }
        }
      end

      v.on(:constructor) do |visitor, type, props|
        visitor.visit(type.type, props)
      end

      v.on(:array) do |visitor, type, props|
        items = visitor.visit(type.element_type)
        { type: 'array', items: }
      end

      v.on(:tuple) do |visitor, type, props|
        items = type.types.map { |t| visitor.visit(t) }
        { type: 'array', prefixItems: items }
      end

      v.on(:tagged_hash) do |visitor, type, props|
        required = Set.new
        result = {
          type: 'object',
          properties: {}
        }

        key = type.key.to_s
        children  = type.types.map { |c| visitor.visit(c) }
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

RSpec.describe Parametric::V2::JSONSchemaVisitor2 do
  subject(:visitor) { described_class.new }

  specify 'simplest possible case with one-level keys and types' do
    type = Parametric::V2::Types::Hash[
      name: Parametric::V2::Types::String.meta(description: 'the name'),
      age?: Parametric::V2::Types::Integer
    ]

    expect(described_class.call(type)).to eq(
      {
        '$schema' => 'http://json-schema.org/draft-08/schema#',
        :type => 'object',
        :properties => {
          'name' => { type: 'string', description: 'the name' },
          'age' => { type: 'integer' }
        },
        :required => %w[name]
      }
    )
  end

  describe 'building properties' do
    specify 'Hash with key and value types' do
      type = Parametric::V2::Types::Hash.schema(
        Parametric::V2::Types::String,
        Parametric::V2::Types::Integer
      )

      expect(described_class.visit(type)).to eq(
        type: 'object',
        patternProperties: { '.*' => { type: 'integer' } }
      )
    end

    specify 'Types::String' do
      type = Parametric::V2::Types::String
      expect(described_class.visit(type)).to eq(type: 'string')
    end

    specify 'Types::Integer' do
      type = Parametric::V2::Types::Integer
      expect(described_class.visit(type)).to eq(type: 'integer')
    end

    specify 'Types::Numeric' do
      type = Parametric::V2::Types::Numeric
      expect(described_class.visit(type)).to eq(type: 'number')
    end

    specify 'Types::Decimal' do
      type = Parametric::V2::Types::Decimal
      expect(described_class.visit(type)).to eq(type: 'number')
    end

    specify 'Float' do
      type = Parametric::V2::Types::Any[Float]
      expect(described_class.visit(type)).to eq(type: 'number')
    end

    specify 'Types::Match with RegExp' do
      type = Parametric::V2::Types::String[/[a-z]+/]
      expect(described_class.visit(type)).to eq(type: 'string', pattern: '[a-z]+')
    end

    specify 'Types::Match with Range' do
      type = Parametric::V2::Types::Integer[10..100]
      expect(described_class.visit(type)).to eq(type: 'integer', minimum: 10, maximum: 100)

      type = Parametric::V2::Types::Integer[10...100]
      expect(described_class.visit(type)).to eq(type: 'integer', minimum: 10, maximum: 99)

      type = Parametric::V2::Types::Integer[10..]
      expect(described_class.visit(type)).to eq(type: 'integer', minimum: 10)

      type = Parametric::V2::Types::Integer[..100]
      expect(described_class.visit(type)).to eq(type: 'integer', maximum: 100)
    end

    specify '#default' do
      # JSON schema's semantics for default values means a default only applies
      # when the key is missing from the payload.
      type = Parametric::V2::Types::String.default('foo')
      expect(described_class.visit(type)).to eq(type: 'string', default: 'foo')

      type = Parametric::V2::Types::String | (Parametric::V2::Types::Nothing >> 'bar')
      expect(described_class.visit(type)).to eq(type: 'string', default: 'bar')

      type = (Parametric::V2::Types::Nothing >> 'bar2') | Parametric::V2::Types::String
      expect(described_class.visit(type)).to eq(type: 'string', default: 'bar2')
    end

    specify '#match' do
      type = Parametric::V2::Types::String.match(/[a-z]+/)
      expect(described_class.visit(type)).to eq(type: 'string', pattern: '[a-z]+')
    end

    specify '#constructor' do
      type = Parametric::V2::Types::Any.constructor(::String)
      expect(described_class.visit(type)).to eq(type: 'string')
    end

    specify 'Types::String >> Types::Integer' do
      type = Parametric::V2::Types::String >> Parametric::V2::Types::Integer
      expect(described_class.visit(type)).to eq(type: 'integer')
    end

    specify 'Types::String | Types::Integer' do
      type = Parametric::V2::Types::String | Parametric::V2::Types::Integer
      expect(described_class.visit(type)).to eq(
        anyOf: [{ type: 'string' }, { type: 'integer' }]
      )
    end

    specify 'Types::Array' do
      type = Parametric::V2::Types::Array[Parametric::V2::Types::String]
      expect(described_class.visit(type)).to eq(
        type: 'array',
        items: { type: 'string' }
      )
    end

    specify 'Types::Boolean' do
      type = Parametric::V2::Types::Boolean
      expect(described_class.visit(type)).to eq(type: 'boolean')
    end

    specify 'Types.optional' do
      type = Parametric::V2::Types::String.optional.default('bar')
      expect(described_class.visit(type)).to eq(
        anyOf: [{ type: 'null' }, { type: 'string' }],
        default: 'bar'
      )
    end

    specify 'Types::True' do
      type = Parametric::V2::Types::True
      expect(described_class.visit(type)).to eq(type: 'boolean')
    end

    specify 'Types::Array with union member type' do
      type = Parametric::V2::Types::Array[
        Parametric::V2::Types::String | Parametric::V2::Types::Hash.schema(
          name: Parametric::V2::Types::String
        )
      ]

      expect(described_class.visit(type)).to eq(
        type: 'array',
        items: {
          anyOf: [
            { type: 'string' },
            {
              type: 'object',
              properties: {
                'name' => { type: 'string' }
              },
              required: ['name']
            }
          ]
        }
      )
    end

    specify 'Types::Tuple' do
      type = Parametric::V2::Types::Tuple[
        'ok',
        Parametric::V2::Types::String,
        Parametric::V2::Types::Integer
      ]

      expect(described_class.visit(type)).to eq(
        type: 'array',
        prefixItems: [
          { const: 'ok', type: 'string' },
          { type: 'string' },
          { type: 'integer' }
        ]
      )
    end

    specify 'Types::Hash.tagged_by' do
      t1 = Parametric::V2::Types::Hash[
        kind: 't1', name: Parametric::V2::Types::String,
        age: Parametric::V2::Types::Integer
      ]
      t2 = Parametric::V2::Types::Hash[kind: 't2', name: Parametric::V2::Types::String]
      type = Parametric::V2::Types::Hash.tagged_by(:kind, t1, t2)

      expect(described_class.visit(type)).to eq(
        type: 'object',
        properties: {
          'kind' => { type: 'string', enum: %w[t1 t2] }
        },
        required: ['kind'],
        allOf: [
          {
            if: {
              properties: {
                'kind' => { const: 't1', type: 'string' }
              }
            },
            then: {
              properties: {
                'kind' => { type: 'string', default: 't1', const: 't1' },
                'name' => { type: 'string' },
                'age' => { type: 'integer' }
              },
              required: %w[kind name age]
            }
          },
          {
            if: {
              properties: {
                'kind' => { const: 't2', type: 'string' }
              }
            },
            then: {
              properties: {
                'kind' => { type: 'string', default: 't2', const: 't2' },
                'name' => { type: 'string' }
              },
              required: %w[kind name]
            }
          }
        ]
      )
    end
  end
end
