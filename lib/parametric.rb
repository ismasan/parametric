require "parametric/version"
require "parametric/support"
require "parametric/registry"
require "parametric/field"
require "parametric/results"
require "parametric/schema"
require "parametric/context"
require "parametric/base_policy"
require 'ostruct'

module Parametric
  def self.registry
    @registry ||= Registry.new
  end

  def self.policy(name, plcy = nil, &block)
    registry.policy name, plcy, &block
  end

  def self.config
    @config ||= OpenStruct.new
  end

  def self.configure
    yield self.config if block_given?
    self.config
  end
end

require 'parametric/default_types'
require 'parametric/policies'
