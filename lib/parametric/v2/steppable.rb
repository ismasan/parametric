# frozen_string_literal: true

module Parametric
  module V2
    TypeError = Class.new(::TypeError)

    module Callable
      def metadata
        DEFAULT_METADATA
      end

      def call(result = Undefined)
        _call(Result.wrap(result))
      end
    end

    module Steppable
      include Callable

      def self.wrap(callable)
        callable.is_a?(Steppable) ? callable : Step.new(callable)
      end

      def cast(value)
        result = call(value)
        raise TypeError, result.error if result.halt?

        result.value
      end

      def ast
        [:custom, metadata, [self]]
      end

      def >>(other)
        And.new(self, Steppable.wrap(other))
      end

      def |(other)
        Or.new(self, Steppable.wrap(other))
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

      class Metadata
        include Steppable

        attr_reader :metadata
        def initialize(metadata)
          @metadata = metadata
        end

        def ast
          [:metadata, metadata, []]
        end

        private def _call(result) = result
      end

      def meta(data = {})
        self >> Metadata.new(data)
      end

      def not(other = self)
        Not.new(other)
      end

      def halt(error: nil)
        Not.new(self, error:)
      end

      def value(val, error = 'invalid value')
        self >> Value.new(val, error)
      end

      def default(val = Undefined, &block)
        val_type = val == Undefined ? Types::Any.transform(&block) : Types::Static[val]
        ((Types::Nothing >> val_type) | self).with_ast(
          [:default, { default: val }, [self.ast]]
        )
      end

      class AST
        include Steppable

        attr_reader :ast

        def initialize(steppable, ast)
          @steppable = steppable
          @ast = ast
        end

        private def _call(result) = @steppable.call(result)
      end

      def with_ast(a)
        AST.new(self, a)
      end

      def optional
        Types::Nil | self
      end

      def present
        Types::Present >> self
      end

      def options(opts = [])
        rule(included_in: opts)
      end

      def rule(rules = {})
        raise ArgumentError, "expected a Hash<rule:value>, ex. #rule(gt: 10), but got #{rules.inspect}" unless rules.is_a?(::Hash)

        self >> Rules.new(rules)
      end

      def format(pattern, error = 'invalid format')
        self >> Format.new(pattern, error)
      end

      def is_a(klass)
        rule(is_a: klass)
      end

      def coerce(type, coercion = nil, &block)
        coercion ||= block
        step = ->(result) {
          type === result.value \
            ? result.success(coercion.call(result.value)) \
            : result.halt(error: "%s can't be coerced" % result.value.inspect )
        }
        self >> step
      end

      def constructor(cns, factory_method = :new, &block)
        block ||= ->(value) { cns.send(factory_method, value) }
        self >> ->(result) { result.success(block.call(result.value)) }
      end

      def pipeline(&block)
        Pipeline.new(self, &block)
      end

      def to_s
        inspect
      end
    end
  end
end
