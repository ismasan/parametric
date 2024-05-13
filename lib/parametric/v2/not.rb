# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Not
      include Steppable

      attr_reader :metadata

      def initialize(step, error: nil)
        @step = step
        @metadata = step.metadata
        @error = error
      end

      def inspect
        %(Not(#{@step.inspect}))
      end

      private def _call(result)
        result = @step.call(result)
        result.success? ? result.halt(error: @error) : result.success
      end
    end
  end
end
