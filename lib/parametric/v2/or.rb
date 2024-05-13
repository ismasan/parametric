# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
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
        return left_result if left_result.success?

        right_result = @right.call(result)
        right_result.success? ? right_result : result.halt(error: [left_result.error, right_result.error].flatten)
      end
    end
  end
end
