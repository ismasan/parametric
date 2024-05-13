# frozen_string_literal: true

module Parametric
  module V2
    TypeError = Class.new(::TypeError)

    module Steppable
      def self.wrap(callable)
        callable.is_a?(Steppable) ? callable : Step.new(callable)
      end

      def metadata
        DEFAULT_METADATA
      end

      def [](value)
        result = call(value)
        raise TypeError, result.error if result.halt?

        result.value
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

      def halt(error: nil)
        Not.new(self, error:)
      end

      def value(val, error = 'invalid value')
        check(error) { |v| val === v }
      end

      def default(val = Undefined, &block)
        (Types::Nothing >> Static.new(val, &block)) | self
      end

      def optional
        Types::Nil | self
      end

      def present
        Types::Present >> self
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
