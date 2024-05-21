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

        list, errors = map_array_elements(result.value)
        # errors = list.each.with_object({}).with_index do |(r, memo), idx|
        #   memo[idx] = r.error unless r.success?
        # end

        values = list.map(&:value)
        return result.success(values) unless errors.any?

        result.halt(error: errors)
      end

      private

      attr_reader :element_type

      def map_array_elements(list)
        # Reuse the same result object for each element
        # to decrease object allocation.
        # We still want to make sure to map element results
        # to an array of different objects (in case a step returns the same result instance)
        element_result = BLANK_RESULT.dup
        errors = {}
        results = list.map.with_index do |e, idx|
          re = element_type.call(element_result.reset(e))
          errors[idx] = re.error unless re.success?
          re.object_id == element_result.object_id ? re.dup : re
        end

        [results, errors]
      end

      class ConcurrentArrayClass < self
        private

        def map_array_elements(list)
          errors = {}

          results = list
            .map { |e| Concurrent::Future.execute { element_type.resolve(e) } }
            .map.with_index do |f, idx|
              val = f.value
              if f.rejected?
                errors[idx] = f.reason
                Result.halt(error: f.reason)
              else
                val
              end
              # f.rejected? ? Result.halt(error: f.reason) : val
            end

          [results, errors]
        end
      end
    end
  end
end
