
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
  end
end
