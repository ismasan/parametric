# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Value
      include Steppable

      def initialize(value, error = 'does not match the value')
        @value = value
        @error = error
      end

      def inspect
        %(Value[value:#{@value}])
      end

      def ast
        [:value, { const: @value, type: @value.class.name.downcase }, []]
      end

      private def _call(result)
        result.value === @value ? result.success(@value) : result.halt(error: @error)
      end
    end
  end
end
