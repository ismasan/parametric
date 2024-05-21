# frozen_string_literal: true

require 'concurrent'
require 'parametric/v2/steppable'
require 'parametric/v2/result'

module Parametric
  module V2
    class ArrayClass
      include Steppable

      def initialize(element_type: Types::Any)
        @element_type = element_type
      end

      def of(element_type)
        self.class.new(element_type:)
      end

      alias_method :[], :of

      def concurrent
        ConcurrentArrayClass.new(element_type:)
      end

      def inspect
        %(#{name}[#{element_type}])
      end

      def ast
        [:array, { type: 'array' }, [element_type.ast]]
      end

      def call(result)
        return result.halt(error: 'is not an Array') unless result.value.is_a?(::Enumerable)

        values, errors = map_array_elements(result.value)
        return result.success(values) unless errors.any?

        result.halt(error: errors)
      end

      private

      attr_reader :element_type

      def map_array_elements(list)
        # Reuse the same result object for each element
        # to decrease object allocation.
        # Steps might return the same result instance, so we map the values directly
        # separate from the errors.
        element_result = BLANK_RESULT.dup
        errors = {}
        values = list.map.with_index do |e, idx|
          re = element_type.call(element_result.reset(e))
          errors[idx] = re.error unless re.success?
          re.value
        end

        [values, errors]
      end

      class ConcurrentArrayClass < self
        private

        def map_array_elements(list)
          errors = {}

          values = list
            .map { |e| Concurrent::Future.execute { element_type.resolve(e) } }
            .map.with_index do |f, idx|
              re = f.value
              if f.rejected?
                errors[idx] = f.reason
              end
              re.value
            end

          [values, errors]
        end
      end
    end
  end
end
