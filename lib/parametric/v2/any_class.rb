# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class AnyClass
      include Steppable

      def ast
        [:any, { type: AnyClass }, BLANK_ARRAY]
      end

      def >>(other)
        Steppable.wrap(other)
      end

      def |(other)
        Steppable.wrap(other)
      end

      def call(result) = result
    end
  end
end
