module Parametric
  class MaybePolicy
    extend Forwardable

    def initialize(policy)
      @policy = policy
    end

    def coerce(value, key, context)
      value.nil? ? nil : policy.coerce(value, key, context)
    end

    def_delegators :policy, :eligible?, :valid?, :meta_data

    private

    attr_reader :policy
  end
end
