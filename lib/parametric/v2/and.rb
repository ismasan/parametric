# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class And
      include Steppable

      attr_reader :left, :right

      def initialize(left, right)
        @left = left
        @right = right
        freeze
      end

      private def _inspect
        %((#{@left.inspect} >> #{@right.inspect}))
      end

      def ast
        [:and, BLANK_HASH, [@left.ast, @right.ast]]
      end

      def call(result)
        result.map(@left).map(@right)
      end
    end
  end
end
