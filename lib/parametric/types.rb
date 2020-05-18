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

  module Types
    TypeError = Class.new(ArgumentError)

    def self.Value(val)
      Value.new(val)
    end

    class NoopValue
      def call(value)
        Result.wrap(value)
      end
    end

    class Type
      NOOP = ->(v) { v }

      attr_reader :name, :hash

      def initialize(name)
        @name = name
        @matchers = {}
        @hash = name
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

      def |(other)
        self[other]
      end

      def call(value)
        # value = sub.call(Result.wrap(value))
        value = Result.wrap(value)
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

      def copy
        self.class.new(name).tap do |i|
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

    class ArrayClass < Type
      def of(element_identity)
        copy.tap do |cp|
          cp.matches ::Array, ->(v) { v.map { |e| element_identity.call(e) } }
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
      def initialize(val)
        super val
        matches val, ->(v) { v }
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
    end

    Integer = Type.new('Integer').tap do |i|
      i.matches ::Numeric, ->(value) { value.to_i }
    end

    Boolean = Type.new('Boolean').tap do |i|
      i.matches TrueClass, ->(v) { v }
      i.matches FalseClass, ->(v) { v }
    end

    Maybe = Type.new('Maybe').tap do |i|
      i.matches NilClass, ->(v) { v }
    end

    CSV = Type.new('CSV').tap do |i|
      i.matches ::String, ->(v) { v.split(/\s*,\s*/) }
    end

    Array = ArrayClass.new('Array').tap do |i|
      i.matches ::Array, ->(v) { v.map { |e| Any.call(e) } }
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
      Boolean = Types::Boolean.copy.tap do |i|
        i.matches /^true$/i, ->(_) { true }
        i.matches '1', ->(_) { true }
        i.matches 1, ->(_) { true }
        i.matches /^false$/i, ->(_) { false }
        i.matches '0', ->(_) { false }
        i.matches 0, ->(_) { false }
      end
    end
  end
end
