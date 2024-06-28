# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Not
      include Steppable

      attr_reader :step

      def initialize(step, errors: nil)
        @step = step
        @errors = errors
        freeze
      end

      private def _inspect
        %(Not(#{@step.inspect}))
      end

      def ast
        [:not, BLANK_HASH, [@step.ast]]
      end

      def call(result)
        result = @step.call(result)
        result.success? ? result.halt(errors: @errors) : result.success
      end
    end
  end
end
