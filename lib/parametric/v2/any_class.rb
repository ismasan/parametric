# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class AnyClass
      include Steppable

      def ast
        [:any, BLANK_HASH, BLANK_ARRAY]
      end

      def >>(steppable)
        Steppable.wrap(steppable)
      end

      def |(other)
        Steppable.wrap(other)
      end

      private def _call(result) = result
    end
  end
end
