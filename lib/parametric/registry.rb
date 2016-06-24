require 'parametric/block_validator'

module Parametric
  class Registry
    attr_reader :policies

    def initialize
      @policies = {}
    end

    def filters
      @policies
    end

    def validator(name, vdtor = nil, &block)
      obj = if vdtor
        vdtor
      else
        BlockValidator.build(:instance_eval, &block)
      end

      policies[name] = obj
      self
    end

    def filter(name, f)
      policies[name] = BlockValidator.build(:coerce, &f)
      self
    end
  end
end

