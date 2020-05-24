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
    assert_result(Types.union(Types::String, Types::Boolean).call('foo'), 'foo', true)
    assert_result(Types.union(Types::String, Types::Boolean).call(true), true, true)
    assert_result(Types.union(Types::String, Types::Boolean).call(11), 11, false)
  end

  specify '.maybe' do
    union = Types::Nil | Types::String
    assert_result(union.call(nil), nil, true)
    assert_result(union.call('foo'), 'foo', true)
    assert_result(union.call(11), 11, false)

    assert_result(Types.maybe(Types::String).call(nil), nil, true)
    assert_result(Types.maybe(Types::String).call('foo'), 'foo', true)
    assert_result(Types.maybe(Types::String).call(11), 11, false)
    assert_result(Types.maybe(Types::Lax::String).call(11), '11', true)
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
      Types::Array.of(Types.value('a') | Types.value('b')).call(['a', 'b', 'a']),
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

    assert_result(Types.value('foo').call('foo'), 'foo', true)
    assert_result(Types.value('foo').call('bar'), 'bar', false)
  end

  specify 'nested' do
    type = Types::Lax::String[Types.value(1)]
    assert_result(type.call(1), '1', true)
    assert_result(type.call('11'), '11', false)
  end

  describe 'traits' do
    it 'includes a default :present trait for all types, checking on nil values' do
      blank_slate = Types::Type.new('Blank').tap do |i|
        i.matches(::Object) { |v| v }
      end

      expect(blank_slate.call('foo').trait(:present)).to be true
      expect(blank_slate.call('').trait(:present)).to be true
      expect(blank_slate.call(nil).trait(:present)).to be false
    end

    it 'can register custom traits' do
      type = Types::String.copy.tap do |i|
        i.trait :polite, ->(v) { v.start_with?('Mr.') }
      end

      expect(type.call('Mr. Ismael').trait(:polite)).to be true
      expect(type.call('Ismael').trait(:polite)).to be false
    end

    it 'copies traits' do
      type1 = Types::String.copy.tap do |i|
        i.trait :polite, ->(v) { v.start_with?('Mr.') }
      end

      type2 = type1.copy
      expect(type2.call('Mr. Ismael').trait(:polite)).to be true
    end

    it 'registers :present for String' do
      expect(Types::String.call('foo').trait(:present)).to be true
      expect(Types::String.call('').trait(:present)).to be false
    end
  end

  specify 'traits' do
    default = Types::Default.new(Types::String, 'nope')
    assert_result(default.call('yes'), 'yes', true)
    assert_result(default.call(''), 'nope', true)
    assert_result(Types::String.default('aa').call(''), 'aa', true)

    assert_result(Types::TraitValidator.new(Types::String.default('aa'), :present).call(''), 'aa', true)
    assert_result(Types::Default.new(Types::TraitValidator.new(Types::String, :present), 'aa').call(''), '', false)
  end

  # field(:name).type(:string).with_title('Mr.')

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