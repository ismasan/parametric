# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class ValueClass
      include Steppable

      def initialize(value = Undefined)
        @value = value
        @error = "must be equal to #{@value}"
      end

      def [](value)
        self.class.new(value)
      end

      def inspect
        %(Value[#{@value}])
      end

      def ast
        [:value, { const: @value, type: @value.class.name.downcase }, BLANK_ARRAY]
      end

      private def _call(result)
        result.value === @value ? result.success(@value) : result.halt(error: @error)
      end
    end
  end
end
