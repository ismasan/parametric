# frozen_string_literal: true

require 'parametric/v2/resultable'

module Parametric
  module V2
    class Result
      include Resultable

      attr_reader :value

      class << self
        def success(value)
          Success.new(value)
        end

        def halt(value = nil, error: nil)
          Halt.new(value, error:)
        end

        def wrap(value)
          return value if value.is_a?(Resultable)

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

        def halt(val = value, error: nil)
          Result.halt(val, error:)
        end
      end

      class Halt < self
        attr_reader :error

        def initialize(value, error: nil)
          @error = error
          super value
        end

        def success?
          false
        end

        def halt?
          true
        end

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
