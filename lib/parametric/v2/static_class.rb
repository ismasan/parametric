# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class StaticClass
      include Steppable

      def initialize(value = Undefined)
        @value = value
      end

      def [](value)
        self.class.new(value)
      end

      def inspect
        %(Static[#{@value.inspect}])
      end

      def ast
        [:static, { default: @value, const: @value, type: @value.class.name.downcase }, []]
      end

      private def _call(result)
        result.success(@value)
      end
    end
  end
end
