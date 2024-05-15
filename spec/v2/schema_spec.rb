# frozen_string_literal: true

require 'spec_helper'
require 'parametric/v2/schema'
require 'parametric/v2/types'

module Test
  module Types
    include Parametric::V2::Types
  end
end

RSpec.describe Parametric::V2::Schema do
  describe 'a schema with nested schemas' do
    subject(:schema) do
      described_class.new do |sc|
        sc.field(:title).type(Test::Types::String).default('Mr')
        sc.field(:name).type(Test::Types::String)
        sc.field?(:age).type(Test::Types::Lax::Integer)
        sc.field(:friend).schema do |s|
          s.field(:name).type(Test::Types::String)
        end
        sc.field(:friends).array do |f|
          f.field(:name).type(Test::Types::String).default('Anonymous')
          f.field(:age).type(Test::Types::Lax::Integer)
        end
      end
    end

    it 'coerces a nested data structure' do
      payload = {
        name: 'Ismael',
        age: '42',
        friend: {
          name: 'Joe'
        },
        friends: [
          { name: 'Joan', age: 44 },
          { age: '45' }
        ]
      }

      assert_result(
        schema.call(payload),
        {
          title: 'Mr',
          name: 'Ismael',
          age: 42,
          friend: {
            name: 'Joe'
          },
          friends: [
            { name: 'Joan', age: 44 },
            { name: 'Anonymous', age: 45 }
          ]
        },
        true
      )
    end

    it 'returns errors for invalid data' do
      result = schema.call({ friend: {} })
      expect(result.success?).to be false
      expect(result.error[:name]).to eq('must be a String')
      expect(result.error[:friend][:name]).to eq('must be a String')
    end

    specify '#fields' do
      field = schema.fields[:name]
      expect(field.key).to eq(:name)
    end
  end

  specify 'optional keys' do
    schema = described_class.new do |s|
      s.field(:name).type(Test::Types::String)
      s.field?(:age).type(Test::Types::Lax::Integer)
    end

    assert_result(schema.call({name: 'Ismael', age: '42'}), {name: 'Ismael', age: 42}, true)
    assert_result(schema.call({name: 'Ismael'}), {name: 'Ismael'}, true)
  end

  specify 'reusing schemas' do
    friend_schema = described_class.new do |s|
      s.field(:name).type(Test::Types::String)
    end

    schema = described_class.new do |sc|
      sc.field(:title).type(Test::Types::String).default('Mr')
      sc.field(:name).type(Test::Types::String)
      sc.field?(:age).type(Test::Types::Lax::Integer)
      sc.field(:friend).schema friend_schema
    end

    assert_result(schema.call({name: 'Ismael', age: '42', friend: { name: 'Joe' }}), {title: 'Mr', name: 'Ismael', age: 42, friend: { name: 'Joe' }}, true)
  end

  specify 'merge with #+' do
    s1 = described_class.new do |sc|
      sc.field(:name).type(Test::Types::String)
    end
    s2 = described_class.new do |sc|
      sc.field?(:name).type(Test::Types::String)
      sc.field(:age).type(Test::Types::Integer).default(10)
    end
    s3 = s1 + s2
    assert_result(s3.call, { age: 10 }, true)
    assert_result(s3.call(name: 'Joe', foo: 1), { name: 'Joe', age: 10 }, true)

    s4 = s1.merge(s2)
    assert_result(s4.call(name: 'Joe', foo: 1), { name: 'Joe', age: 10 }, true)
  end

  specify 'Field#meta' do
    field = described_class::Field.new(:name).type(Test::Types::String).meta(foo: 1).meta(bar: 2)
    expect(field.metadata).to eq(type: ::String, foo: 1, bar: 2)
    expect(field.meta_data).to eq(field.metadata)
  end

  specify 'Field#options' do
    field = described_class::Field.new(:name).type(Test::Types::String).options(%w(aa bb cc))
    assert_result(field.call('aa'), 'aa', true)
    assert_result(field.call('cc'), 'cc', true)
    assert_result(field.call('dd'), 'dd', false)
    expect(field.metadata[:options]).to eq(%w(aa bb cc))
  end

  specify 'Field#optional' do
    field = described_class::Field.new(:name).type(Test::Types::String.transform { |v| "Hello #{v}" }).optional
    assert_result(field.call('Ismael'), 'Hello Ismael', true)
    assert_result(field.call(nil), nil, true)
  end

  specify 'Field#present' do
    field = described_class::Field.new(:name).present
    assert_result(field.call('Ismael'), 'Ismael', true)
    assert_result(field.call(nil), nil, false)
    expect(field.call(nil).error).to eq('must be present')
  end

  specify 'Field#required' do
    field = described_class::Field.new(:name).required
    assert_result(field.call, Parametric::V2::Undefined, false)
    assert_result(field.call(nil), nil, true)
    expect(field.call.error).to eq('is required')
  end

  specify 'self-contained Array type' do
    array_type = Test::Types::Array[Test::Types::Integer | Test::Types::String.transform(&:to_i)]
    schema = described_class.new do |sc|
      sc.field(:numbers).type(array_type)
    end

    assert_result(schema.call(numbers: [1, 2, '3']), {numbers: [1, 2, 3]}, true)
  end

  private

  def assert_result(result, value, is_success, debug: false)
    byebug if debug
    expect(result.value).to eq value
    expect(result.success?).to be is_success
  end
end
