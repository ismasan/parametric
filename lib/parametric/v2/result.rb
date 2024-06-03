# frozen_string_literal: true

module Parametric
  module V2
    class Result
      class << self
        def success(value)
          new(value)
        end

        def halt(value = nil, error: nil)
          new(value, success: false, error:)
        end

        def wrap(value)
          return value if value.is_a?(Result)

          success(value)
        end
      end

      attr_reader :value, :error

      def initialize(value, success: true, error: nil)
        @value = value
        @success = success
        @error = error
        freeze
      end

      def success? = @success
      def halt? = !@success

      def inspect
        %(<#{self.class}[#{success? ? 'success' : 'halt'}]##{object_id} value:#{value.inspect} error:#{error.inspect}>)
      end

      def reset(val)
        @value = val
        @success = true
        @error = nil
        self
      end

      def success(val = value)
        self.class.success(val)
      end

      def halt(val = value, error: nil)
        self.class.halt(val, error: error)
      end
    end
  end
end
