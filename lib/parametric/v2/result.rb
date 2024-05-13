# frozen_string_literal: true

module Parametric
  module V2
    class Result
      attr_reader :value

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

      def initialize(value)
        @value = value
      end

      class Success < self
        def success(v = value)
          v == value ? self : Result.success(v)
        end

        def success? = true
        def halt? = false

        def halt(val = value, error: nil)
          Result.halt(val, error:)
        end

        def map(fn)
          fn.call(self)
        end
      end

      class Halt < self
        attr_reader :error

        def initialize(value, error: nil)
          @error = error
          super value
        end

        def success? = false
        def halt? = true

        def map(_)
          self
        end

        def success
          Result.success(value)
        end
      end
    end
  end
end
