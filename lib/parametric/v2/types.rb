# frozen_string_literal: true

require 'bigdecimal'

module Parametric
  module V2
    Rules.define :eq, 'must be equal to %<value>s' do |result, value|
      value == result.value
    end
    Rules.define :not_eq, 'must not be equal to %<value>s' do |result, value|
      value != result.value
    end
    Rules.define :gt, 'must be greater than %<value>s' do |result, value|
      value < result.value
    end
    Rules.define :lt, 'must be greater than %<value>s' do |result, value|
      value > result.value
    end
    Rules.define :gte, 'must be greater or equal to %<value>s' do |result, value|
      value <= result.value
    end
    Rules.define :lte, 'must be greater or equal to %<value>s' do |result, value|
      value >= result.value
    end
    Rules.define :match, 'must match %<value>s', metadata_key: :pattern do |result, value|
      value === result.value
    end
    Rules.define :format, 'must match format %<value>s' do |result, value|
      value === result.value
    end
    Rules.define :included_in, 'must be included in %<value>s', metadata_key: :options do |result, value|
      value.include? result.value
    end
    Rules.define :excluded_from, 'must not be included in %<value>s' do |result, value|
      !value.include?(result.value)
    end
    Rules.define :respond_to, 'must respond to %<value>s' do |result, value|
      Array(value).all? { |m| result.value.respond_to?(m) }
    end
    Rules.define :is_a, 'must be a %<value>s', metadata_key: :type do |result, value|
      result.value.is_a? value
    end
    Rules.define :size, 'must be of size %<value>s', metadata_key: :size do |result, value|
      value === result.value.size
    end

    module Types
      extend TypeRegistry

      Any = AnyClass.new
      Nothing = Any.rule(eq: Undefined)
      String = Any.is_a(::String)
      Symbol = Any.is_a(::Symbol)
      Numeric = Any.is_a(::Numeric)
      Integer = Any.is_a(::Integer)
      Static = StaticClass.new
      Value = ValueClass.new
      Nil = Any.is_a(::NilClass)
      True = Any.is_a(::TrueClass)
      False = Any.is_a(::FalseClass)
      Boolean = (True | False).with_ast([:boolean, { type: 'boolean' }, []])
      Array = ArrayClass.new
      Tuple = TupleClass.new
      Hash = HashClass.new
      Interface = InterfaceClass.new
      Blank = (
        Nothing \
        | Nil \
        | String.value(BLANK_STRING) \
        | Hash.value(BLANK_HASH) \
        | Array.value(BLANK_ARRAY)
      )

      Present = Blank.halt(error: 'must be present')
      Split = String.transform(::String) { |v| v.split(/\s*,\s*/) }

      module Lax
        String = Types::String \
                 | Any.coerce(BigDecimal) { |v| v.to_s('F') } \
                 | Any.coerce(::Numeric, &:to_s)

        Symbol = Types::Symbol \
          | Any.coerce(::String, &:to_sym)

        Integer = Types::Numeric.transform(::Integer, &:to_i) \
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

        Nil = Nil | (String[BLANK_STRING] >> nil)
      end
    end
  end
end
