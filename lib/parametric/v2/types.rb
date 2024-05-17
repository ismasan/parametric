# frozen_string_literal: true

require 'bigdecimal'
require 'parametric/v2/result'
require 'parametric/v2/type_registry'
require 'parametric/v2/steppable'
require 'parametric/v2/step'
require 'parametric/v2/and'
require 'parametric/v2/pipeline'
require 'parametric/v2/rules'
require 'parametric/v2/static'
require 'parametric/v2/value'
require 'parametric/v2/format'
require 'parametric/v2/not'
require 'parametric/v2/or'
require 'parametric/v2/tuple'
require 'parametric/v2/array_class'
require 'parametric/v2/hash_class'

module Parametric
  module V2
    class UndefinedClass
      def inspect
        %(Undefined)
      end
    end
    Undefined = UndefinedClass.new.freeze

    DEFAULT_METADATA = {}.freeze
    DEFAULT_ERROR_MESSAGE = 'is invalid'
    BLANK_STRING = ''
    BLANK_ARRAY = [].freeze
    BLANK_HASH = DEFAULT_METADATA

    Rules.define :eq, 'must be equal to %{value}' do |result, value|
      value == result.value
    end
    Rules.define :not_eq, 'must not be equal to %{value}' do |result, value|
      value != result.value
    end
    Rules.define :gt, 'must be greater than %{value}' do |result, value|
      value < result.value
    end
    Rules.define :lt, 'must be greater than %{value}' do |result, value|
      value > result.value
    end
    Rules.define :gte, 'must be greater or equal to %{value}' do |result, value|
      value <= result.value
    end
    Rules.define :lte, 'must be greater or equal to %{value}' do |result, value|
      value >= result.value
    end
    Rules.define :match, 'must match %{value}' do |result, value|
      value === result.value
    end
    Rules.define :format, 'must match format %{value}' do |result, value|
      value === result.value
    end
    Rules.define :included_in, 'must be included in %{value}', metadata_key: :options do |result, value|
      value.include? result.value
    end
    Rules.define :excluded_from, 'must not be included in %{value}' do |result, value|
      !value.include?(result.value)
    end
    Rules.define :respond_to, 'must respond to %{value}' do |result, value|
      Array(value).all? { |m| result.value.respond_to?(m) }
    end
    Rules.define :is_a, 'must be a %{value}', metadata_key: :type do |result, value|
      result.value.is_a? value
    end
    Rules.define :size, 'must be of size %{value}', metadata_key: :size do |result, value|
      value === result.value.size
    end

    class AnyClass
      include Steppable

      def ast
        [:any, {}, []]
      end

      def >>(steppable)
        Steppable.wrap(steppable)
      end

      def |(other)
        Steppable.wrap(other)
      end

      private def _call(result) = result
    end

    module Types
      extend TypeRegistry

      Any = AnyClass.new
      Nothing = Any.rule(eq: Undefined)
      String = Any.is_a(::String)
      Numeric = Any.is_a(::Numeric)
      Integer = Any.is_a(::Integer)
      Nil = Any.is_a(::NilClass)
      True = Any.is_a(::TrueClass)
      False = Any.is_a(::FalseClass)
      Boolean = (True | False).with_ast([:boolean, { type: 'boolean'}, []])
      Array = ArrayClass.new
      Tuple = TupleClass.new
      Hash = HashClass.new
      Blank = (
        Nothing \
        | Nil \
        | String.value(BLANK_STRING) \
        | Hash.value(BLANK_HASH) \
        | Array.value(BLANK_ARRAY)
      )

      Present = Blank.halt(error: 'must be present')
      Split = String.transform { |v| v.split(/\s*,\s*/) }

      def self.static(val = Undefined, &block)
        Static.new(val, &block)
      end

      def self.value(...)
        Any.value(...)
      end

      module Lax
        String = Types::String \
                 | Any.coerce(BigDecimal) { |v| v.to_s('F') } \
                 | Any.coerce(::Numeric, &:to_s)

        Integer = Types::Numeric.transform(&:to_i) \
                  | Any.coerce(/^\d+$/, &:to_i) \
                  | Any.coerce(/^\d+.\d*?$/, &:to_i)
      end

      module Forms
        True = Types::True \
               | Types::String >> Any.coerce(/^true$/i) { |_| true } \
               | Any.coerce('1') { |_| true } \
               | Any.coerce(1) { |_| true }

        False = Types::False \
                | Types::String >> Any.coerce(/^false$/i) { |_| false } \
                | Any.coerce('0') { |_| false } \
                | Any.coerce(0) { |_| false }

        Boolean = True | False
      end
    end
  end
end
