require 'forwardable'

module Parametric
  class MaybePolicy
    extend Forwardable

    def initialize(policy)
      @policy = policy
    end

    def coerce(value, key, context)
      value.nil? ? nil : policy.coerce(value, key, context)
    end

    def valid?(value, key, payload)
      value.nil? ? true : policy.valid?(value, key, payload)
    end

    def eligible?(value, key, payload)
      value.nil? ? false : policy.eligible?(value, key, payload)
    end

    def include_non_eligible_in_ouput?
      true
    end

    def_delegators :policy, :meta_data, :message

    private

    attr_reader :policy
  end
end
