# frozen_string_literal: true

module Parametric
  module V2
    class Result
      class << self
        def success(value)
          Success.new(value)
        end

        def halt(value = nil, error: nil)
          Halt.new(value, error:)
        end

        def wrap(value)
          return value if value.is_a?(Result)

          success(value)
        end
      end

      attr_reader :value, :error

      def initialize(value, error: nil)
        @value = value
        @error = error
      end

      def success? = true
      def halt? = false

      def inspect
        %(<#{self.class}##{object_id} value:#{value.inspect} error:#{error.inspect}>)
      end

      def reset(val)
        @value = val
        @error = nil
        self
      end

      def success(val = value)
        Result.success(val)
      end

      def halt(val = value, error: nil)
        Result.halt(val, error:)
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
