# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class HashMap
      include Steppable

      def initialize(key_type, value_type)
        @key_type, @value_type = key_type, value_type
      end

      def ast
        [:hash_map, BLANK_HASH, [@key_type.ast, @value_type.ast]]
      end

      private def _call(result)
        failed = result.value.lazy.filter_map do |key, value|
          key_r, value_r = @key_type.call(key), @value_type.call(value)
          if !key_r.success?
            [:key, key, key_r]
          elsif !value_r.success?
            [:value, value, value_r]
          end
        end
        if (first = failed.next)
          field, val, halt = failed.first
          return result.halt(error: "#{field} #{val.inspect} #{halt.error}")
        end
      rescue StopIteration
        result
      end
    end
  end
end
