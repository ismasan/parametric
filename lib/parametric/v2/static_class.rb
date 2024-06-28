# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class StaticClass
      include Steppable

      attr_reader :value

      def initialize(value = Undefined)
        raise ArgumentError, 'value must be frozen' unless value.frozen?

        @value = value
        freeze
      end

      def [](value)
        self.class.new(value)
      end

      private def _inspect
        %(#{name}[#{@value.inspect}])
      end

      def ast
        [:static, { default: @value, const: @value, type: @value.class }, BLANK_ARRAY]
      end

      def call(result)
        result.success(@value)
      end
    end
  end
end
