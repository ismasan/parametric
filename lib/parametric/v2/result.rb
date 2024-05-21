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
      end

      def success? = @success
      def halt? = !@success

      def inspect
        %(<#{self.class}[#{success? ? 'success' : 'halt'}]##{object_id} value:#{value.inspect}>)
      end

      def success(val = value)
        if val == value
          @value = val
          @success = true
          self
        else
          self.class.success(val)
        end
      end

      def halt(val = value, error: nil)
        if val == value && error == @error
          @value = val
          @error = error
          @success = false
          self
        else
          self.class.halt(val, error: error)
        end
      end
    end
  end
end
