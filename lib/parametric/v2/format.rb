# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class Format
      include Steppable

      def initialize(pattern, error)
        raise ArgumentError, 'pattern must be a Regexp or respond to #===' unless pattern.respond_to?(:===)

        @pattern = pattern
        @error = error
      end

      def ast
        [:format, { pattern: @pattern }, BLANK_ARRAY]
      end

      private def _call(result)
        if @pattern === result.value.to_s
          result
        else
          result.halt(error: @error)
        end
      end
    end
  end
end
