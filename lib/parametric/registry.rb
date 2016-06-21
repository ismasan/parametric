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
        klass = Class.new(BlockValidator)
        klass.instance_eval &block
        klass
      end

      policies[name] = obj
      self
    end

    def filter(name, f)
      klass = Class.new(BlockValidator)
      klass.coerce(&f)
      policies[name] = klass
      self
    end
  end
end

