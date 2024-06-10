# frozen_string_literal: true

module Parametric
  module V2
    class Result
      class << self
        def success(value)
          Success.new(value)
        end

        def halt(value = nil, errors: nil)
          Halt.new(value, errors:)
        end

        def wrap(value)
          return value if value.is_a?(Result)

          success(value)
        end
      end

      attr_reader :value, :errors

      def initialize(value, errors: nil)
        @value = value
        @errors = errors
      end

      def success? = true
      def halt? = false

      def inspect
        %(<#{self.class}##{object_id} value:#{value.inspect} errors:#{errors.inspect}>)
      end

      def reset(val)
        @value = val
        @errors = nil
        self
      end

      def success(val = value)
        Result.success(val)
      end

      def halt(val = value, errors: nil)
        Result.halt(val, errors:)
      end

      class Success < self
        def map(callable)
          callable.call(self)
        end
      end

      class Halt < self
        def success? = false
        def halt? = true

        def map(_)
          self
        end
      end
    end
  end
end
