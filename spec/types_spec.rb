# frozen_string_literal: true

require 'spec_helper'
require 'bigdecimal'
require 'parametric/types'

include Parametric

RSpec.describe Types do
  specify Types::String do
    assert_result(Types::String.call('aa'), 'aa', true)
    assert_result(Types::String.call(10), 10, false)
  end

  specify Types::Lax::String do
    assert_result(Types::Lax::String.call('aa'), 'aa', true)
    assert_result(Types::Lax::String.call(11), '11', true)
    assert_result(Types::Lax::String.call(11.10), '11.1', true)
    assert_result(Types::Lax::String.call(BigDecimal('111.2011')), '111.2011', true)
    assert_result(Types::String.call(true), true, false)
  end

  specify Types::Lax::Integer do
    assert_result(Types::Lax::Integer.call(113), 113, true)
    assert_result(Types::Lax::Integer.call(113.10), 113, true)
    assert_result(Types::Lax::Integer.call('113'), 113, true)
    assert_result(Types::Lax::Integer.call('113.10'), 113, true)
    assert_result(Types::Lax::Integer.call('nope'), 'nope', false)
  end

  specify Types::Boolean do
    assert_result(Types::Boolean.call(true), true, true)
    assert_result(Types::Boolean.call(false), false, true)
    assert_result(Types::Boolean.call('true'), 'true', false)
  end

  specify Types::Forms::Boolean do
    assert_result(Types::Forms::Boolean.call(true), true, true)
    assert_result(Types::Forms::Boolean.call(false), false, true)
    assert_result(Types::Forms::Boolean.call('true'), true, true)

    assert_result(Types::Forms::Boolean.call('false'), false, true)
    assert_result(Types::Forms::Boolean.call('1'), true, true)
    assert_result(Types::Forms::Boolean.call('0'), false, true)
    assert_result(Types::Forms::Boolean.call(1), true, true)
    assert_result(Types::Forms::Boolean.call(0), false, true)

    assert_result(Types::Forms::Boolean.call('nope'), 'nope', false)
  end

  specify Types::Union do
    union = Types::String | Types::Boolean | Types::Integer
    assert_result(union.call('foo'), 'foo', true)
    assert_result(union.call(false), false, true)
    assert_result(union.call(10), 10, true)
    assert_result(union.call({}), {}, false)
    assert_result(Types::Union[Types::String, Types::Boolean].call('foo'), 'foo', true)
    assert_result(Types::Union[Types::String, Types::Boolean].call(true), true, true)
    assert_result(Types::Union[Types::String, Types::Boolean].call(11), 11, false)
  end

  specify Types::Maybe do
    union = Types::Nil | Types::String
    assert_result(union.call(nil), nil, true)
    assert_result(union.call('foo'), 'foo', true)
    assert_result(union.call(11), 11, false)

    assert_result(Types::Maybe[Types::String].call(nil), nil, true)
    assert_result(Types::Maybe[Types::String].call('foo'), 'foo', true)
    assert_result(Types::Maybe[Types::String].call(11), 11, false)
    assert_result(Types::Maybe[Types::Lax::String].call(11), '11', true)
  end

  specify Types::CSV do
    assert_result(
      Types::CSV.call('one,two, three , four'),
      %w[one two three four],
      true
    )
  end

  specify Types::Array do
    assert_result(Types::Array.call([]), [], true)
    assert_result(
      Types::Array.of(Types::Boolean).call([true, true, false]),
      [true, true, false],
      true
    )
    assert_result(
      Types::Array.of(Types::Boolean).call([true, 'nope', false]),
      [true, 'nope', false],
      false
    )
    assert_result(
      Types::Array.of(Types.Value('a') | Types.Value('b')).call(['a', 'b', 'a']),
      %w[a b a],
      true
    )
  end

  specify Types::Any do
    obj = Struct.new(:name).new('Joe')

    assert_result(Types::Any.call(1), 1, true)
    assert_result(Types::Any.call('foobar'), 'foobar', true)
    assert_result(Types::Any.call(obj), obj, true)
  end

  specify Types::Value do
    assert_result(Types::Value.new(1).call(1), 1, true)
    assert_result(Types::Value.new(1).call(10), 10, false)
    assert_result(Types::Value.new('foo').call('foo'), 'foo', true)
    assert_result(Types::Value.new('foo').call('bar'), 'bar', false)

    assert_result(Types.Value('foo').call('foo'), 'foo', true)
    assert_result(Types.Value('foo').call('bar'), 'bar', false)
  end

  # specify Types::Default do
  #   assert_result(Types::String.default('foo').call('bar'), 'bar', true)
  #   assert_result(Types::String.default('foo').call(''), 'foo', true)
  #   assert_result(Types::String.default('foo').call(11), 11, false)
  #   assert_result(Types::String.default('foo').call(0), 0, false)
  #   assert_result(Types::String.default('foo').call(nil), nil, false)
  # end

  # field(:name).type(:string).default('foo')

  private

  def assert_result(result, value, is_success, debug: false)
    byebug if debug
    expect(result.value).to eq value
    expect(result.success?).to be is_success
  end
end
