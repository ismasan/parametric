# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Or
      include Steppable

      attr_reader :left, :right

      def initialize(left, right)
        @left = left
        @right = right
        freeze
      end

      private def _inspect
        %((#{@left.inspect} | #{@right.inspect}))
      end

      def call(result)
        left_result = @left.call(result)
        return left_result if left_result.success?

        right_result = @right.call(result)
        right_result.success? ? right_result : result.halt(errors: [left_result.errors, right_result.errors].flatten)
      end
    end
  end
end
