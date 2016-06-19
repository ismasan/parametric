require 'parametric/block_validator'

module Parametric
  class Registry
    attr_reader :filters, :validators

    def initialize
      @filters = {}
      @validators = {}
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
      filters[name] = f
    end
  end
end

