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

      private def _inspect
        %(#{name}[#{@value.inspect}])
      end

      def ast
        [:value, { const: @value, type: @value.class }, BLANK_ARRAY]
      end

      def call(result)
        @value === result.value ? result : result.halt(errors: @error)
      end
    end
  end
end
