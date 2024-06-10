# frozen_string_literal: true

require 'parametric/v2/steppable'

module Parametric
  module V2
    class TaggedHash
      include Steppable

      def initialize(hash_type, key, types)
        @hash_type = hash_type
        @key = Key.wrap(key)
        @types = types

        raise ArgumentError, 'all types must be HashClass' if @types.size == 0 || @types.any? do |t|
                                                                !t.is_a?(HashClass)
                                                              end
        raise ArgumentError, "all types must define key #{@key}" unless @types.all? { |t| !!t.at_key(@key) }

        # types are assumed to have static values for the index field :key
        @index = @types.each.with_object({}) do |t, memo|
          memo[t.at_key(@key).resolve.value] = t
        end
      end

      def ast
        [
          :tagged_hash,
          { key: @key.to_sym },
          @types.map(&:ast)
        ]
      end

      def call(result)
        result = @hash_type.call(result)
        return result unless result.success?

        child = @index[result.value[@key.to_sym]]
        return result.halt(errors: "expected :#{@key.to_sym} to be one of #{@index.keys.join(', ')}") unless child

        child.call(result)
      end
    end
  end
end
