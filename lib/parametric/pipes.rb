# frozen_string_literal: true

require 'bigdecimal'
require 'concurrent'

module Parametric
  module Pipes
    Undefined = Object.new.freeze

    DEFAULT_METADATA = {}.freeze

    module Resultable
      def success?
        true
      end

      def halt?
        false
      end

      def map(fn)
        fn.call(self)
      end
    end

    class Result
      include Resultable

      attr_reader :value

      class << self
        def success(value)
          Success.new(value)
        end

        def halt(value = nil, error: nil)
          Halt.new(value, error:)
        end

        def wrap(value)
          return value if value.is_a?(Resultable)

          success(value)
        end
      end

      def initialize(value)
        @value = value
      end

      class Success < self
        def success(v = value)
          v == value ? self : Result.success(v)
        end

        def halt(val = value, error: nil)
          Result.halt(val, error:)
        end
      end

      class Halt < self
        attr_reader :error

        def initialize(value, error: nil)
          @error = error
          super value
        end

        def success?
          false
        end

        def halt?
          true
        end

        def map(_)
          self
        end

        def success
          Result.success(value)
        end
      end
    end

    module Steppable
      def self.wrap(callable)
        callable.is_a?(Steppable) ? callable : Step.new(callable)
      end

      def metadata
        DEFAULT_METADATA
      end

      def call(result = Undefined)
        _call(Result.wrap(result))
      end

      def >>(other)
        Chain.new(self, Steppable.wrap(other))
      end

      def transform(callable = nil, &block)
        callable ||= block
        transformation = ->(result) {
          new_value = callable.call(result.value)
          result.success(new_value)
        }

        self >> transformation
      end

      def check(error = 'did not pass the check', &block)
        a_check = ->(result) {
          block.call(result.value) ? result : result.halt(error:)
        }

        self >> a_check
      end

      def |(other)
        Or.new(self, Steppable.wrap(other))
      end

      def meta(data = {})
        Step.new(self, metadata: metadata.merge(data))
      end

      def not(other = self)
        Not.new(other)
      end

      def value(val, error = 'invalid value')
        check(error) { |v| val === v }
      end

      def static(val = Undefined, &block)
        self >> Static.new(val, &block)
      end

      def default(val = Undefined, &block)
        (Types::Nothing >> Static.new(val, &block)) | self
      end

      def optional
        Types::Nil | self
      end

      def rule(rules = {})
        raise ArgumentError, "expected a Hash<rule:value>, ex. #rule(gt: 10), but got #{rules.inspect}" unless rules.is_a?(::Hash)

        self >> Rules.new(rules)
      end

      def is_a(klass)
        rule(is_a: klass)
      end

      def coerce(type, coercion = nil, &block)
        coercion ||= block
        step = ->(result) {
          type === result.value \
            ? result.success(coercion.call(result.value)) \
            : result.halt(error: "%s can't be coerced" % result.value )
        }
        self >> step
      end

      def constructor(cns, factory_method = :new, &block)
        block ||= ->(value) { cns.send(factory_method, value) }
        self >> ->(result) { result.success(block.call(result.value)) }
      end

      def to_s
        inspect
      end
    end

    class Rules
      class Registry
        class UndefinedRuleError < KeyError
          def initialize(rule_name)
            @rule_name = rule_name
          end

          def message
            %(No rule registered with :#{@rule_name})
          end
        end

        RuleDef = Data.define(:name, :error_tpl, :callable) do
          def error_for(result, value)
            return nil if callable.call(result, value)

            error_tpl % { value: value }
          end
        end

        def initialize
          @definitions = {}
        end

        def define(name, error_tpl, callable = nil, &block)
          name = name.to_sym
          callable ||= block
          @definitions[name] = RuleDef.new(name:, error_tpl:, callable:)
        end

        def resolve(rules)
          rules.map { |(name, value)| [@definitions.fetch(name.to_sym) { raise UndefinedRuleError.new(name) }, value] }
        end
      end

      include Steppable

      def self.registry
        @registry ||= Registry.new
      end

      def self.define(...)
        registry.define(...)
      end

      def initialize(rules)
        @rules = self.class.registry.resolve(rules)
      end

      private def _call(result)
        errors = @rules.map { |(ruledef, value)| ruledef.error_for(result, value) }.compact
        return result unless errors.any?

        result.halt(error: errors.join(', '))
      end
    end

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
    Rules.define :included_in, 'must be included in %{value}' do |result, value|
      value.include? result.value
    end
    Rules.define :excluded_from, 'must not be included in %{value}' do |result, value|
      !value.include?(result.value)
    end
    Rules.define :respond_to, 'must respond to %{value}' do |result, value|
      Array(value).all? { |m| result.value.respond_to?(m) }
    end
    Rules.define :is_a, 'must be a %{value}' do |result, value|
      result.value.is_a? value
    end

    class Static
      include Steppable

      def initialize(value = Undefined, &block)
        @inspect_value = nil
        @value = value == Undefined ? block : -> { value }
      end

      def inspect
        %(Static[value:#{@value}])
      end

      private def _call(result)
        result.success(@value.call)
      end
    end

    class Not
      include Steppable

      attr_reader :metadata

      def initialize(step)
        @step = step
        @metadata = step.metadata
      end

      def inspect
        %(Not(#{@step.inspect}))
      end

      private def _call(result)
        result = @step.call(result)
        result.success? ? result.halt : result.success
      end
    end

    class Chain
      include Steppable

      def initialize(left, right)
        @left = left
        @right = right
      end

      def metadata
        @left.metadata.merge(@right.metadata)
      end

      def inspect
        %((#{@left.inspect} >> #{@right.inspect}))
      end

      private def _call(result)
        result.map(@left).map(@right)
      end
    end

    class Or
      include Steppable

      def initialize(left, right)
        @left, @right = left, right
      end

      def metadata
        @left.metadata.merge(@right.metadata)
      end

      def inspect
        %((#{@left.inspect} | #{@right.inspect}))
      end

      private def _call(result)
        left_result = @left.call(result)
        left_result.success? ? left_result : @right.call(result)
      end
    end

    class Step
      include Steppable

      attr_reader :metadata

      def initialize(callable = nil, metadata: DEFAULT_METADATA, &block)
        @metadata = metadata
        @callable = callable || block
      end

      def inspect
        %(Step[#{metadata.map { |(k,v)| "#{k}:#{v}" }.join(', ')}])
      end

      private def _call(result)
        @callable.call(result)
      end
    end

    Any = Step.new { |r| r }

    class ArrayClass
      include Steppable

      attr_reader :metadata

      def initialize(element_type: Any)
        @element_type = element_type
        @metadata = @element_type.metadata.merge(type: 'Array')
      end

      def of(element_type)
        self.class.new(element_type:)
      end

      def concurrent
        ConcurrentArrayClass.new(element_type:)
      end

      def inspect
        %(Array<#{element_type}>)
      end

      private

      attr_reader :element_type

      private def _call(result)
        return result.halt(error: 'is not an Enumerable') unless result.value.is_a?(::Enumerable)

        list = map_array_elements(result.value)
        errors = list.each.with_object({}).with_index do |(r, memo), idx|
          memo[idx] = r.error unless r.success?
        end

        values = list.map(&:value)
        return result.success(values) unless errors.any?

        result.halt(error: errors)
      end

      def map_array_elements(list)
        list.map { |e| element_type.call(e) }
      end
    end

    class ConcurrentArrayClass < ArrayClass
      private

      def map_array_elements(list)
        list
          .map { |e| Concurrent::Future.execute { element_type.call(e) } }
          .map do |f|
            val = f.value
            f.rejected? ? Result.halt(error: f.reason) : val
          end
      end
    end

    class Key
      OPTIONAL_EXP = /(\w+)(\?)?$/

      def self.wrap(key)
        key.is_a?(Key) ? key : new(key)
      end

      def initialize(key)
        key_s = key.to_s
        match = OPTIONAL_EXP.match(key_s)
        @key = match[1]
        @optional = !!match[2]
      end

      def to_sym
        @key.to_sym
      end

      def optional?
        @optional
      end
    end

    class HashClass
      include Steppable

      def initialize(schema = {})
        @_schema = schema
        freeze
      end

      def schema(hash)
        self.class.new(_schema.merge(wrap_keys(hash)))
      end

      def &(other)
        self.class.new(_schema.merge(other._schema))
      end

      def inspect
        %(Hash[#{_schema.map{ |(k,v)| [k, v.inspect].join(':') }.join(' ')}])
      end

      protected

      attr_reader :_schema

      private

      def _call(result)
        return result.halt(error: 'must be a Hash') unless result.value.is_a?(::Hash)
        return result unless _schema.any?

        input = result.value
        errors = {}
        output = _schema.each.with_object({}) do |(key, field), ret|
          if input.key?(key.to_sym)
            r = field.call(input[key.to_sym])
            errors[key.to_sym] = r.error unless r.success?
            ret[key.to_sym] = r.value
          elsif !key.optional?
            r = field.call(Undefined)
            errors[key.to_sym] = r.error unless r.success?
            ret[key.to_sym] = r.value unless r.value == Undefined
          end
        end

        errors.any? ? result.halt(output, error: errors) : result.success(output)
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

    module TypeNamespace
      def define(const_name, &type_builder)
        const_set(const_name, type_builder.call.meta(type: [ancestors.last.to_s, const_name].join('::')))
      end
    end

    module Types
      extend TypeNamespace

      define(:Nothing) { Any.rule(eq: Undefined) }
      define(:String) { Any.is_a(::String) }
      define(:Numeric) { Any.is_a(::Numeric) }
      define(:Integer) { Any.is_a(::Integer) }
      define(:Nil) { Any.is_a(::NilClass) }
      define(:True) { Any.is_a(::TrueClass) }
      define(:False) { Any.is_a(::FalseClass) }
      define(:Boolean) { (True | False) }

      Array = ArrayClass.new
      Hash = HashClass.new

      module Lax
        extend TypeNamespace

        define(:String) do
          Types::String \
            | Any.coerce(BigDecimal) { |v| v.to_s('F') } \
            | Any.coerce(::Numeric, &:to_s)
        end

        define(:Integer) do
          Types::Numeric.transform(&:to_i) \
            | Any.coerce(/^\d+$/, &:to_i) \
            | Any.coerce(/^\d+.\d*?$/, &:to_i)
        end
      end

      module Forms
        extend TypeNamespace

        define(:True) do
          Types::True \
            | Any.coerce(/^true$/i) { |_| true } \
            | Any.coerce('1') { |_| true } \
            | Any.coerce(1) { |_| true }
        end

        define(:False) do
          Types::False \
            | Any.coerce(/^false$/i) { |_| false } \
            | Any.coerce('0') { |_| false } \
            | Any.coerce(0) { |_| false }
        end

        define(:Boolean) { True | False }
      end
    end
  end
end
