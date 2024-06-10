# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Or
      include Steppable

      def initialize(left, right)
        @left = left
        @right = right
        freeze
      end

      def inspect
        %((#{@left.inspect} | #{@right.inspect}))
      end

      def ast
        [:or, BLANK_HASH, [@left.ast, @right.ast]]
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
