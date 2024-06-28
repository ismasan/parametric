# frozen_string_literal: true

require 'concurrent'
require 'parametric/v2/steppable'
require 'parametric/v2/result'
require 'parametric/v2/hash_class'

module Parametric
  module V2
    class ArrayClass
      include Steppable

      attr_reader :element_type

      def initialize(element_type: Types::Any)
        @element_type = case element_type
                       when Steppable
                         element_type
                       when ::Hash
                         HashClass.new(element_type)
                       else
                         raise ArgumentError,
                               "element_type #{element_type.inspect} must be a Steppable"
                       end

        freeze
      end

      def of(element_type)
        self.class.new(element_type:)
      end

      alias [] of

      def concurrent
        ConcurrentArrayClass.new(element_type:)
      end

      private def _inspect
        %(#{name}[#{element_type}])
      end

      def ast
        [:array, { type: ::Array }, [element_type.ast]]
      end

      def call(result)
        return result.halt(errors: 'is not an Array') unless result.value.is_a?(::Enumerable)

        values, errors = map_array_elements(result.value)
        return result.success(values) unless errors.any?

        result.halt(errors:)
      end

      private

      def map_array_elements(list)
        # Reuse the same result object for each element
        # to decrease object allocation.
        # Steps might return the same result instance, so we map the values directly
        # separate from the errors.
        element_result = BLANK_RESULT.dup
        errors = {}
        values = list.map.with_index do |e, idx|
          re = element_type.call(element_result.reset(e))
          errors[idx] = re.errors unless re.success?
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
            errors[idx] = f.reason if f.rejected?
            re.value
          end

          [values, errors]
        end
      end
    end
  end
end
