require 'parametric/block_validator'

module Parametric
  class Registry
    attr_reader :policies

    def initialize
      @policies = {}
    end

    def coercions
      @policies
    end

    def policy(name, plcy = nil, &block)
      obj = if plcy
        plcy
      else
        BlockValidator.build(:instance_eval, &block)
      end

      policies[name] = obj
      self
    end
  end
end

