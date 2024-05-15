# frozen_string_literal: true

require 'spec_helper'
require 'parametric/v2/schema'
require 'parametric/v2/types'

RSpec.describe Parametric::V2::Schema do
  specify 'defining a nested schema' do
    schema = described_class.new do |sc|
      sc.field(:title).type(Parametric::V2::Types::String).default('Mr')
      sc.field(:name).type(Parametric::V2::Types::String)
      sc.field?(:age).type(Parametric::V2::Types::Lax::Integer)
      sc.field(:friend).schema do |s|
        s.field(:name).type(Parametric::V2::Types::String)
      end
      sc.field(:friends).array do |f|
        f.field(:name).type(Parametric::V2::Types::String).default('Anonymous')
        f.field(:age).type(Parametric::V2::Types::Lax::Integer)
      end
    end

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

  specify 'reusing schemas' do
    friend_schema = Types::Schema.new do |s|
      s.field(:name).type(:string)
    end

    schema = Types::Schema.new do |sc|
      sc.field(:title).type(:string).default('Mr')
      sc.field(:name).type(:string)
      sc.field?(:age).type(:integer)
      sc.field(:friend).type(:hash).schema friend_schema
    end

    assert_result(schema.call({name: 'Ismael', age: 42, friend: { name: 'Joe' }}), {title: 'Mr', name: 'Ismael', age: 42, friend: { name: 'Joe' }}, true)
  end

  specify 'merge with #&' do
    s1 = Types::Schema.new do |sc|
      sc.field(:name).type(:string)
    end
    s2 = Types::Schema.new do |sc|
      sc.field?(:name).type(:string)
      sc.field(:age).type(:integer).default(10)
    end
    s3 = s1 & s2
    assert_result(s3.call, { age: 10 }, true)
    assert_result(s3.call(name: 'Joe', foo: 1), { name: 'Joe', age: 10 }, true)

    s4 = s1.merge(s2)
    assert_result(s4.call(name: 'Joe', foo: 1), { name: 'Joe', age: 10 }, true)
  end

  describe 'Field#policy(step)' do
    it 'takes steps as objects or registry symbols' do
      email = Types::Any.rule(match: /\w+@\w+\.\w{3}/)
      field = Types::Schema::Field.new
        .type(:string)
        .policy(email)
        .policy(Types::String.transform{ |v| "<#{v}>"})

      assert_result(field.call('user@email.com'), '<user@email.com>', true)
      assert_result(field.call('nope'), 'nope', false)
      assert_result(field.call(1), 1, false)
    end

    it 'takes rule as :rule_name, matcher' do
      field = Types::Schema::Field.new.type(:string).policy(:format, /^Mr\s/)
      assert_result(field.call('Mr Ismael'), 'Mr Ismael', true)
      assert_result(field.call('Ismael'), 'Ismael', false)
    end

    it 'takes rules as hash' do
      field = Types::Schema::Field.new.type(:integer).policy(gte: 10, lte: 20)
      assert_result(field.call(11), 11, true)
      assert_result(field.call(9), 9, false)
      assert_result(field.call(21), 21, false)
    end
  end

  specify 'Field#meta' do
    field = Types::Schema::Field.new.type(:string).meta(foo: 1).meta(bar: 2)
    expect(field.metadata).to eq(type: ::String, foo: 1, bar: 2)
    expect(field.meta_data).to eq(field.metadata)
  end

  specify 'Field#options' do
    field = Types::Schema::Field.new.type(:string).options(%w(aa bb cc))
    assert_result(field.call('aa'), 'aa', true)
    assert_result(field.call('cc'), 'cc', true)
    assert_result(field.call('dd'), 'dd', false)
    expect(field.metadata[:options]).to eq(%w(aa bb cc))
  end

  specify 'Field#declared' do
    field = Types::Schema::Field.new.type(:string).declared.policy(Types::Any.transform { |v| 'Hello %s' % v })
    assert_result(field.call('Ismael'), 'Hello Ismael', true)
    assert_result(field.call(Undefined), Undefined, false)

    with_default = Types::Schema::Field.new.type(:string).declared.default('no')
    assert_result(with_default.call('Ismael'), 'Ismael', true)
    assert_result(with_default.call(Undefined), 'no', true)
  end

  specify 'Field#optional' do
    field = Types::Schema::Field.new.type(:string).optional.policy(Types::Any.transform { |v| 'Hello %s' % v })
    assert_result(field.call('Ismael'), 'Hello Ismael', true)
    assert_result(field.call(nil), nil, false)
  end

  specify 'Field#present' do
    field = Types::Schema::Field.new.present
    assert_result(field.call('Ismael'), 'Ismael', true)
    assert_result(field.call(nil), nil, false)
    expect(field.call(nil).error).to eq('must be present')
  end

  specify 'Field#required' do
    field = Types::Schema::Field.new.required
    assert_result(field.call, Undefined, false)
    assert_result(field.call(nil), nil, true)
    expect(field.call.error).to eq('is required')
  end

  specify 'Field#policy(:split)' do
    field = Types::Schema::Field.new.policy(:split)
    assert_result(field.call('a ,b  ,c'), %w(a b c), true)
    assert_result(field.call('aa'), %w(aa), true)
  end

  context 'with array schemas' do
    specify 'inline array schemas' do
      schema = Types::Schema.new do |sc|
        sc.field(:friends).type(:array).schema do |f|
          f.field(:name).type(:string)
        end
      end

      input = {friends: [{name: 'Joe'}, {name: 'Joan'}]}

      assert_result(schema.call(input), input, true)
    end

    specify 'reusable array schemas' do
      friend_schema = Types::Schema.new do |s|
        s.field(:name).type(:string)
      end

      schema = Types::Schema.new do |sc|
        sc.field(:friends).type(:array).schema friend_schema
      end

      input = {friends: [{name: 'Joe'}, {name: 'Joan'}]}

      assert_result(schema.call(input), input, true)
      schema.call({friends: [{name: 'Joan'}, {}]}).tap do |result|
        expect(result.success?).to be false
        expect(result.error[:friends][1][:name]).not_to be_nil
      end
    end

    specify 'array.of' do
      schema = Types::Schema.new do |sc|
        sc.field(:numbers).type(:array).of(Types::Integer | Types::String.transform(&:to_i))
      end

      assert_result(schema.call(numbers: [1, 2, '3']), {numbers: [1, 2, 3]}, true)
    end

    specify 'self-contained Array type' do
      array_type = Types::Array.of(Types::Integer | Types::String.transform(&:to_i))
      schema = Types::Schema.new do |sc|
        sc.field(:numbers).type(array_type)
      end

      assert_result(schema.call(numbers: [1, 2, '3']), {numbers: [1, 2, 3]}, true)
    end

    specify '#of followed by #policy' do
      schema = Types::Schema.new do |sc|
        sc.field(:numbers).type(:array).of(Types::Integer).policy(:size, 3)
      end

      assert_result(schema.call(numbers: [1, 2, 3]), {numbers: [1, 2, 3]}, true)
      assert_result(schema.call(numbers: [1, 2, 3, 4]), {numbers: [1, 2, 3, 4]}, false)
    end
  end

  private

  def assert_result(result, value, is_success, debug: false)
    byebug if debug
    expect(result.value).to eq value
    expect(result.success?).to be is_success
  end
end
