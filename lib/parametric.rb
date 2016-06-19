require "parametric/version"
require "parametric/registry"
require "parametric/field"
require "parametric/results"
require "parametric/schema"
require "parametric/context"

module Parametric

  def self.registry
    @registry ||= Registry.new
  end

  def self.validator(name, vdtor = nil, &block)
    registry.validator name, vdtor, &block
  end

  def self.filter(name, f)
    registry.filter name, f
  end
end

require 'parametric/validators'
require 'parametric/filters'
