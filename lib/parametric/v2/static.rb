# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Static
      include Steppable

      def initialize(value = Undefined, &block)
        @value = value == Undefined ? block : -> { value }
      end

      def inspect
        %(Static[value:#{@value}])
      end

      def ast
        value = @value.call
        [:static, { default: value, const: value, type: value.class.name.downcase }, []]
      end

      private def _call(result)
        result.success(@value.call)
      end
    end
  end
end
