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

  def self.policy(name, plcy = nil, &block)
    registry.policy name, plcy, &block
  end

  def self.coercion(name, f)
    registry.coercion name, f
  end
end

require 'parametric/default_types'
require 'parametric/validators'
require 'parametric/coercions'
