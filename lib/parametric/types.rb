# frozen_string_literal: true

module Parametric
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

    attr_reader :traits

    def initialize(value, error: nil, traits: {})
      @value, @error = value, error
      @traits = traits
    end

    def trait(key)
      val = traits.fetch(key)
      val.respond_to?(:call) ? @traits[key] = val.call(value) : val
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

      value.success(@coercion.(value.value))
    end
  end

  module Types
    def self.value(val)
      Value.new(val)
    end

    def self.union(*types)
      types.reduce(&:|)
    end

    def self.maybe(type)
      Types::Nil | type
    end

    class BaseValue
      def self.call(value)
        Result.wrap(value)
      end
    end

    module ChainableType
      def call(value)
        result = sub.call(Result.wrap(value))
        return result unless result.success?

        _call(result)
      end

      def default(val = Undefined, &block)
        Default.new(self, val, &block)
      end

      def options(opts)
        Enum.new(self, opts)
      end

      private

      def _call(result)
        result
      end
    end

    class Type
      include ChainableType

      NOOP = ->(v) { v }

      attr_reader :name, :hash

      def initialize(name, sub: BaseValue, traits: {})
        @name = name
        @matchers = {}
        @hash = name
        @sub = sub
        @traits = traits
        # Register a default :present trait
        trait(:present) { |v| !v.nil? } unless @traits.key?(:present)
      end

      def to_s
        %(<#{self.class.name} [#{name}]>)
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

      def trait(key, callable = nil, &block)
        callable ||= block
        raise ArgumentError, 'a trait needs a callable object or a block' unless callable

        @traits[key] = callable
        self
      end

      def [](child)
        copy(sub: child)
      end

      def |(other)
        copy.tap do |i|
          i.matches other
        end
      end

      def copy(sub: nil, traits: nil)
        self.class.new(name, sub: sub || @sub, traits: traits || @traits).tap do |i|
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

      def match(result)
        matchers.each do |m|
          v = m.(Result.success(result.value))
          return v if v.success?
        end

        return result.failure("#{result.value.inspect} (#{result.value.class}) cannot be coerced into #{name}. No matcher registered.")
      end

      private

      attr_reader :sub

      def _call(result)
        result = match(result)
        return result unless result.success?

        if err = errors_for_coercion_output(result.value)
          result.failure(err, value_for_coercion_output(result.value))
        else
          @traits.each do |key, callable|
            result.traits[key] = callable
          end
          result.success(value_for_coercion_output(result.value))
        end
      end

    end

    class ArrayClass < Type
      def of(element_type)
        copy.tap do |cp|
          cp.matches ::Array, ->(v) { v.map { |e| element_type.(e) } }
        end
      end

      private

      def errors_for_coercion_output(list)
        failure = list.find(&:failure?)
        failure ? failure.error : nil
      end

      def value_for_coercion_output(list)
        list.map &:value
      end
    end

    class Value < Type
      def initialize(val, *_args)
        super
        matches val, ->(v) { v }
      end
    end

    class TraitValidator
      include ChainableType

      def initialize(sub, trait_key)
        @sub, @trait_key = sub, trait_key
      end

      private

      attr_reader :sub # required by ChainableType

      def _call(result)
        result.trait(@trait_key) ? result : result.failure("expected value to be #{@trait_key}, but got #{result.value.inspect}")
      end
    end

    class Default
      include ChainableType

      def initialize(sub, val = Undefined, &block)
        @sub = sub
        val = block if val == Undefined
        @val = val.respond_to?(:call) ? val : -> { val }
      end

      def copy(sub: nil, traits: nil)
        @sub.copy.default(@val)
      end

      def |(other)
        (@sub | other).default(@val)
      end

      private

      attr_reader :sub

      def _call(result)
        result.trait(:present) ? result : (result.traits[:present] = true;result.success(@val.call))
      end
    end

    class Enum
      include ChainableType

      def initialize(sub, opts)
        @sub, @opts = sub, Array(opts)
      end

      private

      attr_reader :sub, :opts

      def _call(result)
        val = Array(result.value)
        return result.failure("expected value to be included in #{opts.inspect}, but got #{result.value.inspect}") if (val - opts).any?

        result
      end
    end

    Union = Type.new('Union')

    Any = Type.new('Any').tap do |i|
      i.matches ::Object, ->(value) { value }
    end

    Nil = Type.new('Nil').tap do |i|
      i.matches ::NilClass, ->(v) { v }
    end

    String = Type.new('String').tap do |i|
      i.matches ::String, ->(value) { value }
      i.trait(:present) { |v| v != '' }
    end

    Integer = Type.new('Integer').tap do |i|
      i.matches ::Numeric, ->(value) { value.to_i }
    end

    True = Type.new('True').tap do |i|
      i.matches TrueClass, ->(v) { v }
    end

    False = Type.new('False').tap do |i|
      i.matches FalseClass, ->(v) { v }
    end

    Boolean = True | False

    CSV = Type.new('CSV').tap do |i|
      i.matches ::String, ->(v) { v.split(/\s*,\s*/) }
    end

    Array = ArrayClass.new('Array').tap do |i|
      i.matches ::Array, ->(v) { v.map { |e| Any.(e) } }
      i.trait(:present) { |v| v.any? }
    end

    module Lax
      String = Types::String.copy.tap do |i|
        i.matches BigDecimal, ->(value) { value.to_s('F') }
        i.matches Numeric, ->(value) { value.to_s }
      end
      Integer = Types::Integer.copy.tap do |i|
        i.matches /^\d+$/, ->(value) { value.to_i }
        i.matches /^\d+.\d*?$/, ->(value) { value.to_i }
      end
    end

    module Forms
      True = Types::True.copy.tap do |i|
        i.matches /^true$/i, ->(_) { true }
        i.matches '1', ->(_) { true }
        i.matches 1, ->(_) { true }
      end

      False = Types::False.copy.tap do |i|
        i.matches /^false$/i, ->(_) { false }
        i.matches '0', ->(_) { false }
        i.matches 0, ->(_) { false }
      end

      Boolean = True | False
    end
  end
end
