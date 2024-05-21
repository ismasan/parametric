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

        list = map_array_elements(result.value)
        errors = list.each.with_object({}).with_index do |(r, memo), idx|
          memo[idx] = r.error unless r.success?
        end

        values = list.map(&:value)
        return result.success(values) unless errors.any?

        result.halt(error: errors)
      end

      private

      attr_reader :element_type

      def map_array_elements(list)
        list.map { |e| element_type.resolve(e) }
      end

      class ConcurrentArrayClass < self
        private

        def map_array_elements(list)
          list
            .map { |e| Concurrent::Future.execute { element_type.resolve(e) } }
            .map do |f|
              val = f.value
              f.rejected? ? Result.halt(error: f.reason) : val
            end
        end
      end
    end
  end
end
