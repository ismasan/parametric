# frozen_string_literal: true

require 'spec_helper'
require 'parametric/v2'
require 'parametric/v2/json_schema_visitor'

RSpec.describe Parametric::V2::JSONSchemaVisitor do
  subject(:visitor) { described_class }

  specify 'simplest possible case with one-level keys and types' do
    type = Parametric::V2::Types::Hash[
      name: Parametric::V2::Types::String.meta(description: 'the name'),
      age?: Parametric::V2::Types::Integer
    ]

    expect(described_class.call(type)).to eq(
      {
        '$schema' => 'https://json-schema.org/draft-08/schema#',
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

    xspecify 'complex type with AND and OR branches' do
      type = Parametric::V2::Types::String \
        | (Parametric::V2::Types::Integer.transform(::Integer) { |v| v * 2 }).options([2, 4])

      expect(visitor.visit(type)).to eq(
        anyOf: [
          { type: 'string' },
          { type: 'integer', enum: [2, 4] }
        ]
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
