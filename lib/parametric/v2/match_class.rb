# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class MatchClass
      include Steppable

      attr_reader :matcher

      def initialize(matcher = Undefined, error: nil)
        raise TypeError 'matcher must respond to #===' unless matcher.respond_to?(:===)

        @matcher = matcher
        @error = error.nil? ? build_error(matcher) : (error % matcher)
      end

      def inspect
        %(#{name}[#{@matcher.inspect}])
      end

      def call(result)
        @matcher === result.value ? result : result.halt(errors: @error)
      end

      private def build_error(matcher)
        case matcher
        when Class # A class primitive, ex. String, Integer, etc.
          "Must be a #{matcher}"
        when ::String, ::Symbol, ::Numeric, ::TrueClass, ::FalseClass, ::NilClass, ::Array, ::Hash
          "Must be equal to #{matcher}"
        when ::Range
          "Must be within #{matcher}"
        else
          "Must match #{matcher.inspect}"
        end
      end
    end
  end
end
