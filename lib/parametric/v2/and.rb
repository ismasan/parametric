# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class And
      include Steppable

      def initialize(left, right)
        @left = left
        @right = right
      end

      def inspect
        %((#{@left.inspect} >> #{@right.inspect}))
      end

      def ast
        [:and, BLANK_HASH, [@left.ast, @right.ast]]
      end

      private def _call(result)
        result = @left.call(result)
        result.success? ? @right.call(result) : result
      end
    end
  end
end
