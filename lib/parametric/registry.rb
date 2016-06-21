require 'parametric/block_validator'

module Parametric
  class Registry
    attr_reader :validators

    def initialize
      @filters = {}
      @validators = {}
    end

    def filters
      @validators
    end

    def validator(name, vdtor = nil, &block)
      obj = if vdtor
        vdtor
      else
        klass = Class.new(BlockValidator)
        klass.instance_eval &block
        klass
      end

      validators[name] = obj
      self
    end

    def filter(name, f)
      klass = Class.new(BlockValidator)
      klass.coerce(&f)
      validators[name] = klass
      self
    end
  end
end

