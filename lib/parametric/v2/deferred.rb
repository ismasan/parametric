# frozen_string_literal: true

require 'thread'

module Parametric
  module V2
    class Deferred
      include Steppable

      def initialize(definition)
        @lock = Mutex.new
        @definition = definition
        @cached_type = nil
        # freeze
      end

      def call(result)
        cached_type.call(result)
      end

      private def cached_type
        @lock.synchronize do
          @cached_type = @definition.call
          self.define_singleton_method(:cached_type) do
            @cached_type
          end
          @cached_type
        end
      end
    end
  end
end

