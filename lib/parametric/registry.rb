require 'parametric/block_validator'

module Parametric
  class Registry
    attr_reader :policies

    def initialize
      @policies = {}
    end

    def coercions
      policies
    end

    def policy(name, plcy = nil, &block)
      policies[name] = (plcy || BlockValidator.build(:instance_eval, &block))
      self
    end
  end
end

