# frozen_string_literal: true

module Parametric
  # Adapt legacy policies to the new policy interface
  class PolicyAdapter
    class PolicyRunner
      def initialize(policy, key, value, payload, context)
        @policy, @key, @raw_value, @payload, @context = policy, key, value, payload, context
      end

      # The Policy Runner interface
      def eligible?
        @policy.eligible?(@raw_value, @key, @payload)
      end

      def valid?
        @policy.valid?(value, @key, @payload)
      end

      def value
        @value ||= @policy.coerce(@raw_value, @key, @context)
      end

      def message
        @policy.message
      end
    end

    def initialize(policy)
      @policy = policy
    end

    # The Policy Factory interface
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
