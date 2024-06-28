# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Transform
      include Steppable

      attr_reader :target_type

      def initialize(target_type, callable)
        @target_type = target_type
        @callable = callable
      end

      def ast
        [:transform, { type: @target_type }, []]
      end

      def call(result)
        result.success(@callable.call(result.value))
      end
    end
  end
end
