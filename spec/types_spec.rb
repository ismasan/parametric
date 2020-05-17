# frozen_string_literal: true

require 'spec_helper'
require 'bigdecimal'

class Undefined;end

class Result
  attr_reader :value, :error

  def self.success(value)
    new(value)
  end

  def self.failure(error)
    new(nil, error: error)
  end

  def self.wrap(value)
    return value if value.is_a?(Result)

    new(value)
  end

  def initialize(value, error: nil)
    @value, @error = value, error
  end

  def success?
    error.nil?
  end

  def failure?
    !!error
  end

  def success(v)
    @value = v
    @error = nil
    self
  end

  def failure(err, value = Undefined)
    @error = err
    @value = value unless value == Undefined
    self
  end
end

class PrimitiveMatcher
  attr_reader :hash

  def initialize(type, coercion)
    @type, @coercion = type, coercion
    @hash = type.is_a?(::Class) ? type.name : type.hash.to_s
  end

  def call(value)
    return value.failure("expected #{value.value} to be a #{@type}") unless @type === value.value

    value.success(@coercion.call(value.value))
  end
end

module Identities
  TypeError = Class.new(ArgumentError)

  class NoopValue
    def call(value)
      Result.wrap(value)
    end
  end

  class Identity
    NOOP = ->(v) { v }

    attr_reader :name, :hash

    def initialize(name, type: Undefined, sub: NoopValue.new)
      @name = name
      @matchers = {}
      @sub = sub
      @type = type
      @hash = name
    end

    def type(t = Undefined)
      @type = t unless t == Undefined
      @type
    end

    def matchers
      @matchers.values
    end

    def matches(type, coercion = nil, &block)
      coercion = coercion || block || NOOP
      matcher = if type.respond_to?(:call)
                  type
                elsif type.respond_to?(:===)
                  PrimitiveMatcher.new(type, coercion)
                else
                  raise ArgumentError, "#{type.inspect} is not a valid matcher"
                end
      @matchers[matcher.hash] = matcher
      self
    end

    def [](*children)
      copy.tap do |i|
        children.each do |ch|
          i.matches ch
        end
      end
    end

    def call(value)
      value = sub.call(Result.wrap(value))
      return value unless value.success?

      value = match(value)
      return value unless value.success?
      # return value.failure("expected #{type}, but got #{value.value.inspect}") unless coerced_value.is_a?(type)

      if err = errors_for_coercion_output(value.value)
        value.failure(err, value_for_coercion_output(value.value))
      else
        value.success(value_for_coercion_output(value.value))
      end
    end

    def copy(sub: nil)
      self.class.new(name, type: type, sub: sub || @sub).tap do |i|
        matchers.each do |m|
          i.matches m
        end
      end
    end

    protected

    def errors_for_coercion_output(_)
      nil
    end

    def value_for_coercion_output(v)
      v
    end

      # return value.failure("#{value.value.inspect} cannot be coerced into #{name}") unless matcher
    def match(value)
      matchers.each do |m|
        v = m.call(Result.success(value.value))
        return v if v.success?
      end

      return value.failure("#{value.value.inspect} (#{value.value.class}) cannot be coerced into #{name}. No matcher registered.")
    end

    private

    attr_reader :sub
  end

  class ArrayClass < Identity
    def of(element_identity)
      copy.tap do |cp|
        cp.matches ::Array, ->(v) { v.map { |e| element_identity.call(e) } }
      end
    end

    private

    def errors_for_coercion_output(list)
      failure = list.find { |e| e.is_a?(Result) ? e.failure? : false }
      failure ? failure.error : nil
    end

    def value_for_coercion_output(list)
      list.map { |v| v.is_a?(Result) ? v.value : v }
    end
  end

  Union = Identity.new('Union')
  String = Identity.new('String').tap do |i|
    i.matches ::String, ->(value) { value }
    i.type ::String
  end

  Integer = Identity.new('Integer').tap do |i|
    i.matches ::Numeric, ->(value) { value.to_i }
    i.type ::Integer
  end

  Boolean = Identity.new('Boolean').tap do |i|
    i.matches TrueClass, ->(v) { v }
    i.matches FalseClass, ->(v) { v }
    # i.type [TrueClass, FalseClass]
  end

  Maybe = Identity.new('Maybe').tap do |i|
    i.matches NilClass, ->(v) { v }
  end

  CSV = Identity.new('CSV').tap do |i|
    i.matches ::String, ->(v) { v.split(/\s*,\s*/) }
    i.type ::Array
  end

  Array = ArrayClass.new('Array').tap do |i|
    i.matches ::Array, ->(v) { v }
    i.type ::Array
  end

  module Lax
    String = Identities::String.copy.tap do |i|
      i.matches BigDecimal, ->(value) { value.to_s('F') }
      i.matches Numeric, ->(value) { value.to_s }
    end
    Integer = Identities::Integer.copy.tap do |i|
      i.matches /^\d+$/, ->(value) { value.to_i }
      i.matches /^\d+.\d*?$/, ->(value) { value.to_i }
    end
  end

  module Forms
    Boolean = Identities::Boolean.copy.tap do |i|
      i.matches /^true$/i, ->(_) { true }
      i.matches '1', ->(_) { true }
      i.matches 1, ->(_) { true }
      i.matches /^false$/i, ->(_) { false }
      i.matches '0', ->(_) { false }
      i.matches 0, ->(_) { false }
    end
  end
end

RSpec.describe Identities do
  specify Identities::String do
    assert_result(Identities::String.call('aa'), 'aa', true)
    assert_result(Identities::String.call(10), 10, false)
  end

  specify Identities::Lax::String do
    assert_result(Identities::Lax::String.call('aa'), 'aa', true)
    assert_result(Identities::Lax::String.call(11), '11', true)
    assert_result(Identities::Lax::String.call(11.10), '11.1', true)
    assert_result(Identities::Lax::String.call(BigDecimal('111.2011')), '111.2011', true)
    assert_result(Identities::String.call(true), true, false)
  end

  specify Identities::Lax::Integer do
    assert_result(Identities::Lax::Integer.call(113), 113, true)
    assert_result(Identities::Lax::Integer.call(113.10), 113, true)
    assert_result(Identities::Lax::Integer.call('113'), 113, true)
    assert_result(Identities::Lax::Integer.call('113.10'), 113, true)
    assert_result(Identities::Lax::Integer.call('nope'), 'nope', false)
  end

  specify Identities::Boolean do
    assert_result(Identities::Boolean.call(true), true, true)
    assert_result(Identities::Boolean.call(false), false, true)
    assert_result(Identities::Boolean.call('true'), 'true', false)
  end

  specify Identities::Forms::Boolean do
    assert_result(Identities::Forms::Boolean.call(true), true, true)
    assert_result(Identities::Forms::Boolean.call(false), false, true)
    assert_result(Identities::Forms::Boolean.call('true'), true, true)

    assert_result(Identities::Forms::Boolean.call('false'), false, true)
    assert_result(Identities::Forms::Boolean.call('1'), true, true)
    assert_result(Identities::Forms::Boolean.call('0'), false, true)
    assert_result(Identities::Forms::Boolean.call(1), true, true)
    assert_result(Identities::Forms::Boolean.call(0), false, true)

    assert_result(Identities::Forms::Boolean.call('nope'), 'nope', false)
  end

  specify Identities::Union do
    assert_result(Identities::Union[Identities::String, Identities::Boolean].call('foo'), 'foo', true)
    assert_result(Identities::Union[Identities::String, Identities::Boolean].call(true), true, true)
    assert_result(Identities::Union[Identities::String, Identities::Boolean].call(11), 11, false)
  end

  specify Identities::Maybe do
    assert_result(Identities::Maybe[Identities::String].call(nil), nil, true)
    assert_result(Identities::Maybe[Identities::String].call('foo'), 'foo', true)
    assert_result(Identities::Maybe[Identities::String].call(11), 11, false)
    assert_result(Identities::Maybe[Identities::Lax::String].call(11), '11', true)
  end

  specify Identities::CSV do
    assert_result(
      Identities::CSV.call('one,two, three , four'),
      %w[one two three four],
      true
    )
  end

  specify Identities::Array do
    assert_result(Identities::Array.call([]), [], true)
    assert_result(
      Identities::Array.of(Identities::Boolean).call([true, true, false]),
      [true, true, false],
      true
    )
    assert_result(
      Identities::Array.of(Identities::Boolean).call([true, 'nope', false]),
      [true, 'nope', false],
      false
    )
  end

  private

  def assert_result(result, value, is_success, debug: false)
    byebug if debug
    expect(result.value).to eq value
    expect(result.success?).to be is_success
  end
end
