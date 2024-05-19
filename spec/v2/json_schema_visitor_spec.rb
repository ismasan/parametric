
# frozen_string_literal: true

require 'spec_helper'
require 'parametric/v2/json_schema_visitor'
require 'parametric/v2/types'

RSpec.describe Parametric::V2::JSONSchemaVisitor do
  subject(:visitor) { described_class.new }

  specify 'simplest possible case with one-level keys and types' do
    type = Parametric::V2::Types::Hash.schema(
      name: Parametric::V2::Types::String.meta(description: 'the name'),
      age?: Parametric::V2::Types::Integer
    )

    expect(described_class.call(type.ast)).to eq(
      {
        '$schema' => 'http://json-schema.org/draft-08/schema#',
        :type => 'object',
        :properties => {
          'name' => { type: 'string', description: 'the name' },
          'age' => { type: 'integer' },
        },
        :required => %w[name],
      }
    )
  end

  describe 'building properties' do
    specify 'Hash with key and value types' do
      type = Parametric::V2::Types::Hash.schema(
        Parametric::V2::Types::String,
        Parametric::V2::Types::Integer
      )

      expect(visitor.visit(type.ast)).to eq(
        type: 'object',
        patternProperties: { '.*' => { type: 'integer' } }
      )
    end

    specify 'Types::String' do
      type = Parametric::V2::Types::String
      expect(visitor.visit(type.ast)).to eq(type: 'string')
    end

    specify '#default' do
      type = Parametric::V2::Types::String.default('foo')
      expect(visitor.visit(type.ast)).to eq(type: 'string', default: 'foo')
    end

    specify '#format' do
      type = Parametric::V2::Types::String.format(/[a-z]+/)
      expect(visitor.visit(type.ast)).to eq(type: 'string', pattern: '[a-z]+')
    end

    specify '#options' do
      type = Parametric::V2::Types::String.options(%w[foo bar])
      expect(visitor.visit(type.ast)).to eq(type: 'string', enum: %w[foo bar])
    end

    specify 'Types::String >> Types::Integer' do
      type = Parametric::V2::Types::String >> Parametric::V2::Types::Integer
      expect(visitor.visit(type.ast)).to eq(type: 'integer')
    end

    specify 'Types::String | Types::Integer' do
      type = Parametric::V2::Types::String | Parametric::V2::Types::Integer
      expect(visitor.visit(type.ast)).to eq(
        anyOf: [{ type: 'string' }, { type: 'integer' }]
      )
    end

    specify 'Types::Array' do
      type = Parametric::V2::Types::Array[Parametric::V2::Types::String]
      expect(visitor.visit(type.ast)).to eq(
        type: 'array',
        items: { type: 'string' }
      )
    end

    specify 'Types::Array with union member type' do
      type = Parametric::V2::Types::Array[
        Parametric::V2::Types::String | Parametric::V2::Types::Hash.schema(
          name: Parametric::V2::Types::String
        )
      ]

      expect(visitor.visit(type.ast)).to eq(
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

      expect(visitor.visit(type.ast)).to eq(
        type: 'array',
        prefixItems: [
          { const: 'ok', type: 'string' },
          { type: 'string' },
          { type: 'integer' }
        ]
      )
    end

    specify 'Types::Hash.tagged_by' do
      t1 = Parametric::V2::Types::Hash[kind: 't1', name: Parametric::V2::Types::String, age: Parametric::V2::Types::Integer]
      t2 = Parametric::V2::Types::Hash[kind: 't2', name: Parametric::V2::Types::String]
      type = Parametric::V2::Types::Hash.tagged_by(:kind, t1, t2)

      expect(visitor.visit(type.ast)).to eq(
        type: 'object',
        properties: {
          'kind' => { type: 'string', enum: %w[t1 t2] },
        },
        required: ['kind'],
        allOf: [
          {
            :if => {
              properties: {
                'kind' => { const: 't1', type: 'string' },
              }
            },
            :then => {
              properties: {
                'kind' => { type: 'string', default: 't1', const: 't1'},
                'name' => { type: 'string' },
                'age' => { type: 'integer' }
              },
              required: ['kind', 'name', 'age']
            }
          },
          {
            :if => {
              properties: {
                'kind' => { const: 't2', type: 'string' },
              }
            },
            :then => {
              properties: {
                'kind' => { type: 'string', default: 't2', const: 't2'},
                'name' => { type: 'string' }
              },
              required: ['kind', 'name']
            }
          }
        ]
      )
    end

    specify 'complex type with AND and OR branches' do
      type = Parametric::V2::Types::String \
        | (Parametric::V2::Types::Integer >> Parametric::V2::Types::Any).options(%w[foo bar])

      expect(visitor.visit(type.ast)).to eq(
        anyOf: [
          { type: 'string' },
          { type: 'integer', enum: %w[foo bar] }
        ]
      )
    end

    specify 'recursive type' do
      type = Parametric::V2::Types::Hash[
        value: Parametric::V2::Types::String,
        next: Parametric::V2::Types::Any.defer { linked_list } | Parametric::V2::Types::Nil
      ]

      # TODO: figure out how
      # to represent recursive types in JSON Schema
      expect(visitor.visit(type.ast)).to eq(
        type: 'object',
        properties: {
          'next' => {
            anyOf: [
              {},
              { type: 'null' }
            ]
          },
          'value' => { type: 'string' }
        },
        required: ['value', 'next'],
      )
    end
  end
end
