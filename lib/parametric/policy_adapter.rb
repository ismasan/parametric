# frozen_string_literal: true

module Parametric
  # Adapt legacy policies to the new policy interface
  class PolicyAdapter
    class PolicyRunner
      def initialize(policy, key, value, payload, context)
        @policy, @key, @raw_value, @payload, @context = policy, key, value, payload, context
      end

      # The PolicyRunner interface
      # @return [Boolean]
      def eligible?
        @policy.eligible?(@raw_value, @key, @payload)
      end

      # @return [Boolean]
      def valid?
        @policy.valid?(value, @key, @payload)
      end

      # @return [Any]
      def value
        @value ||= @policy.coerce(@raw_value, @key, @context)
      end

      # @return [String]
      def message
        @policy.message
      end
    end

    def initialize(policy)
      @policy = policy
    end

    # The PolicyFactory interface
    # Buld a Policy Runner, which is instantiated
    # for each field when resolving a schema
    # @param key [Symbol]
    # @param value [Any]
    # @option payload [Hash]
    # @option context [Parametric::Context]
    # @return [PolicyRunner]
    def build(key, value, payload:, context:)
      PolicyRunner.new(@policy, key, value, payload, context)
    end

    def meta_data
      @policy.meta_data
    end

    def key
      @policy.key
    end
  end
end
