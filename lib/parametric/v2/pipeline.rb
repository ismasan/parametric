# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Pipeline
      include Steppable

      class AroundStep
        include Steppable

        attr_reader :metadata

        def initialize(step, block)
          @step, @block = step, block
          @metadata = @step.metadata
        end

        private def _call(result)
          @block.call(@step, result)
        end
      end

      def initialize(type = Types::Any, &setup)
        @type = type
        @around_blocks = []
        if block_given?
          configure(&setup)
          freeze
        end
      end

      def metadata
        @type.metadata
      end

      def call(result)
        @type.call(result)
      end

      def step(callable = nil, &block)
        callable ||= block
        raise ArgumentError, "#step expects an interface #call(Result) Result, but got #{callable.inspect}" unless is_a_step?(callable)

        callable = @around_blocks.reduce(callable) { |cl, bl| AroundStep.new(cl, bl) } if @around_blocks.any?
        @type = @type >> callable
        self
      end

      def around(callable = nil, &block)
        @around_blocks << (callable || block)
        self
      end

      private

      def configure(&setup)
        case setup.arity
        when 1
          setup.call(self)
        when 0
          instance_eval(&setup)
        else
          raise ArgumentError, 'setup block must have arity of 0 or 1'
        end
      end

      def is_a_step?(callable)
        return false unless callable.respond_to?(:call)

        true
      end
    end
  end
end
