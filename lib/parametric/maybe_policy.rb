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

    def_delegators :policy, :eligible?, :meta_data, :message

    private

    attr_reader :policy
  end
end
