# frozen_string_literal: true

require 'bigdecimal'

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

    class Registry
      def initialize(parent: {})
        @parent = parent
        @registry = {}
      end

      def []=(key, type)
        @registry[key] = type
      end

      def [](key)
        @registry.fetch(key) { @parent[key] }
      end
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

      def transform(val = Undefined, &block)
        self > Transform.new(val, &block)
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
        if failure
          idx = list.index(failure)
          {idx => failure.error}
        else
          nil
        end
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

      def to_s
        %(<#{self.class.name} #{types.map(&:to_s).join(' | ')}>)
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

    class Key
      def self.wrap(key)
        key.is_a?(Key) ? key : new(key)
      end

      def initialize(key, optional: false)
        @key, @optional = key, optional
      end

      def to_sym
        @key
      end

      def optional?
        @optional
      end
    end

    class HashClass < Type
      def initialize(schema = {})
        super 'Hash'
        @_schema = schema
        rule!(:is_a?, ::Hash)
        freeze
      end

      def schema(hash)
        self.class.new(_schema.merge(wrap_keys(hash)))
      end

      def &(other)
        self.class.new(_schema.merge(other._schema))
      end

      def >(other)
        HashPipeline.new([self, other])
      end

      class HashPipeline < Type
        def initialize(steps)
          super 'pipeline'
          @steps = Array(steps)
        end

        private def _call(result)
          initial_value = result.value
          @steps.reduce(result) do |r, step|
            r1 = step.call(r)
            r1.success? ? (r1.success(initial_value.merge(r1.value))) : r1
          end
        end
      end

      protected

      attr_reader :_schema

      private

      def _call(result)
        result = run_rules(coerce(result))
        return result unless result.success?
        return result unless _schema.any?

        input = result.value
        errors = {}
        output = _schema.each.with_object({}) do |(key, field), ret|
          if input.key?(key.to_sym)
            r = field.call(input[key.to_sym])
            errors[key.to_sym] = r.error if r.failure?
            ret[key.to_sym] = r.value
          elsif key.optional?
            # do nothing, omit key
          else
            r = field.call(Undefined)
            errors[key.to_sym] = r.error if r.failure?
            ret[key.to_sym] = r.value unless r.value == Undefined
          end
        end

        errors.any? ? Result.success(output).failure(errors) : result.success(output)
      end

      def wrap_keys(hash)
        case hash
        when ::Array
          hash.map { |e| wrap_keys(e) }
        when ::Hash
          hash.each.with_object({}) do |(k, v), ret|
            ret[Key.wrap(k)] = wrap_keys(v)
          end
        else
          hash
        end
      end
    end

    Hash = HashClass.new

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

    BaseRegistry = Registry.new.tap do |r|
      r[:string] = Types::String
      r[:integer] = Types::Integer
      r[:hash] = Types::Hash
    end

    class Schema
      def initialize(registry: BaseRegistry, &block)
        @_schema = {}
        @registry = registry
        @hash = Types::Hash
        setup(&block) if block_given?
      end

      def setup(&block)
        yield self
        @hash = Types::Hash.schema(@_schema)
        freeze
      end

      def freeze
        super
        @_schema.freeze
        self
      end

      def field(key)
        _schema[Key.new(key)] = Field.new(registry)
      end

      def field?(key)
        _schema[Key.new(key, optional: true)] = Field.new(registry)
      end

      def schema(sc = nil, &block)
        if sc
          @hash = sc
          freeze
          self
        else
          setup(&block) if block_given?
        end
      end

      def call(value)
        hash.call(value)
      end

      private

      attr_reader :_schema, :registry, :hash

      class SchemaArray
        def initialize(registry:)
          @registry = registry
          @_type = Types::Array
        end

        def schema(sc = nil, &block)
          sc ||= Types::Schema.new(registry: registry, &block)
          @_type = @_type.of(sc)
          self
        end

        def call(result)
          _type.call(result)
        end

        private

        attr_reader :registry, :_type
      end

      class Field
        attr_reader :_type

        def initialize(registry)
          @registry = registry
          @_type = Types::Any
        end

        def type(type_symbol)
          if type_symbol == :hash
            @_type = Types::Schema.new(registry: registry)
          elsif type_symbol == :array
            @_type = SchemaArray.new(registry: registry)
          else
            @_type = registry[type_symbol]
            self
          end
        end

        def default(v, &block)
          @_type = @_type.default(v, &block)
          self
        end

        def call(result)
          @_type.call(result)
        end

        private

        attr_reader :registry
      end
    end
  end
end
