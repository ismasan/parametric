# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Not
      include Steppable

      def initialize(step, error: nil)
        @step = step
        @error = error
      end

      def inspect
        %(Not(#{@step.inspect}))
      end

      def ast
        [:not, BLANK_HASH, [@step.ast]]
      end

      def call(result)
        result = @step.call(result)
        result.success? ? result.halt(error: @error) : result.success
      end
    end
  end
end
