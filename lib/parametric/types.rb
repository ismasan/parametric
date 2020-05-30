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

  class RuleRegistry
    def initialize
      @rules = {}
    end

    def define(predicate, callable = nil, &block)
      callable ||= block
      @rules[predicate] = callable
    end

    def [](predicate)
      @rules.fetch(predicate)
    end
  end

  class RuleSet
    include Enumerable

    class Rule < Struct.new(:predicate, :args)
      def inspect_line(value)
        %[#{predicate}(#{value.inspect}, #{args.map(&:inspect).join(', ')})]
      end

      def inspect
        %[#{predicate}(#{args.map(&:inspect).join(', ')})]
      end
    end

    def initialize(registry, rules: Set.new)
      @registry = registry
      @rules = rules
    end

    def freeze
      super
      @rules.freeze
      self
    end

    def clone
      self.class.new(@registry).tap do |rs|
        @rules.each do |r|
          rs.rule r.predicate, *r.args
        end
      end
    end

    def rule(predicate, *args)
      @rules << Rule.new(predicate, args)
    end

    def each(&block)
      @rules.each(&block)
    end

    def call(value)
      failure = @rules.find { |r| !@registry[r.predicate].call(value, *r.args) }
      failure ? [false, %[failed #{failure.inspect_line(value)}]] : [true, nil]
    end
  end

  class PrimitiveCoercion
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
    Rules = RuleRegistry.new.tap do |r|
      r.define :is_a? do |value, type|
        value.is_a?(type)
      end
      r.define :included_in? do |value, array|
        !(Array(value) - array).any?
      end
      r.define :eq? do |actual, expected|
        actual == expected
      end
    end

    def self.value(val)
      Value.new(val)
    end

    def self.union(*types)
      types.reduce(&:|)
    end

    def self.maybe(type)
      Types::Nil | type
    end

    module ChainableType
      def call(value = Undefined)
        result = Result.wrap(value)
        return result unless result.success?

        _call(result)
      end

      def default(val = Undefined, &block)
        (Nothing > Static.new(val, &block)) | self
      end

      def optional
        Types::Nil | self
      end

      def options(opts)
        rule(:included_in?, opts)
      end

      def >(other)
        Pipeline.new([self, other])
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

      def initialize(name, rule_set: RuleSet.new(Rules))
        @name = name
        @coercions = {}
        @hash = name
        @rule_set = rule_set
      end

      def freeze
        super
        @coercions.freeze
        @rule_set.freeze
        self
      end

      def to_s
        %(<#{self.class.name} [#{name}] #{rule_set.map(&:inspect).join(' ')}>)
      end

      def inspect
        to_s
      end

      def coercions
        @coercions.values
      end

      def coercion(type, cr = nil, &block)
        clone do |i|
          i.coercion!(type, cr, &block)
        end
      end

      protected def coercion!(type, cr = nil, &block)
        cr = cr || block || NOOP
        matcher = if type.respond_to?(:call)
                    type
                  elsif type.respond_to?(:===)
                    PrimitiveCoercion.new(type, cr)
                  else
                    raise ArgumentError, "#{type.inspect} is not a valid matcher"
                  end
        @coercions[matcher.hash] = matcher
        self
      end

      def rule(predicate, *args)
        clone do |i|
          i.rule!(predicate, *args)
        end
      end

      protected def rule!(predicate, *args)
        rule_set.rule(predicate, *args)
        self
      end

      def |(other)
        Union.new(self, other)
      end

      def clone(&block)
        self.class.new(name, rule_set: rule_set.clone).tap do |i|
          coercions.each do |m|
            i.coercion! m
          end
          yield i if block_given?
          i.freeze
        end
      end

      protected

      def errors_for_coercion_output(_)
        nil
      end

      def value_for_coercion_output(v)
        v
      end

      private

      attr_reader :rule_set

      def coerce(result)
        coercions.each do |m|
          v = m.(Result.success(result.value))
          return v if v.success?
        end

        result
      end

      def run_rules(result)
        success, err = rule_set.call(result.value)
        return result.failure(err) unless success

        result
      end

      def _call(result)
        result = run_rules(coerce(result))
        return result unless result.success?

        if err = errors_for_coercion_output(result.value)
          result.failure(err, value_for_coercion_output(result.value))
        else
          result.success(value_for_coercion_output(result.value))
        end
      end
    end

    class Static < Type
      def initialize(value = Undefined, &block)
        super 'static'
        @_value = value == Undefined ? block : ->{ value }
      end

      private def _call(result)
        result.success(@_value.call)
      end
    end

    class Transform < Type
      def initialize(callable = Undefined, &block)
        super 'transform'
        @_value = callable == Undefined ? block : callable
      end

      private def _call(result)
        result.success @_value.call(result.value)
      end
    end

    class Pipeline < Type
      def initialize(steps)
        super 'pipeline'
        @steps = Array(steps)
      end

      private def _call(result)
        @steps.reduce(result) do |r, step|
          step.call(r)
        end
      end
    end

    class ArrayClass < Type
      def of(element_type)
        coercion(::Array) { |v| v.map { |e| element_type.(e) } }
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
        rule! :eq?, val
      end
    end

    class Union < Type
      def initialize(*types)
        super 'Union'
        @types = types
      end

      def clone(&block)
        self.class.new(*@types).tap do |i|
          yield i if block_given?
          i.freeze
        end
      end

      private

      attr_reader :types

      def _call(result)
        last_result = result
        types.each do |t|
          last_result = t.(Result.success(result.value))
          return last_result if last_result.success?
        end

        last_result
      end
    end

    Nothing = Type.new('Nothing').rule(:eq?, Undefined)

    Any = Type.new('Any').rule(:is_a?, ::Object)

    Nil = Type.new('Nil').rule(:is_a?, ::NilClass)

    String = Type.new('String').rule(:is_a?, ::String)

    Integer = Type.new('Integer')
      .rule(:is_a?, ::Numeric)
      .coercion(::Numeric, &:to_i)

    True = Type.new('True').rule(:is_a?, ::TrueClass)

    False = Type.new('False').rule(:is_a?, ::FalseClass)

    Boolean = True | False

    CSV = Type.new('CSV')
      .coercion(::String) { |v| v.split(/\s*,\s*/) }
      .rule(:is_a?, ::Array)

    Array = ArrayClass.new('Array')
      .coercion(::Array) { |v| v.map { |e| Any.(e) } }
      .rule(:is_a?, ::Array)

    module Lax
      String = Types::String
        .coercion(BigDecimal) { |v| v.to_s('F') }
        .coercion(Numeric, &:to_s)

      Integer = Types::Integer
        .coercion(/^\d+$/, &:to_i)
        .coercion(/^\d+.\d*?$/, &:to_i)
    end

    module Forms
      True = Types::True
        .coercion(/^true$/i) { |_| true }
        .coercion('1') { |_| true }
        .coercion(1) { |_| true }

      False = Types::False
        .coercion(/^false$/i) { |_| false }
        .coercion('0') { |_| false }
        .coercion(0) { |_| false }

      Boolean = True | False
    end
  end
end
