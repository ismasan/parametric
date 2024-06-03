# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class StaticClass
      include Steppable

      def initialize(value = Undefined)
        @value = value
        freeze
      end

      def [](value)
        self.class.new(value)
      end

      def inspect
        %(#{name}[#{@value.inspect}])
      end

      def ast
        [:static, { default: @value, const: @value, type: @value.class.name.downcase }, BLANK_ARRAY]
      end

      def call(result)
        result.success(@value)
      end
    end
  end
end
